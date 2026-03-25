module Kms = Drm.Kms

let open_device (d : Drm.Device.Info.t) =
  match d.primary_node with
  | None -> None
  | Some primary ->
    let dev = Unix.openfile primary [O_RDWR; O_CLOEXEC] 0 in
    if Drm.Device.is_kms dev then (
      if Drm.Device.is_master dev then Some dev
      else (
        Fmt.epr "WARNING: Not DRM master for graphics device %S (probably something else is using it)@." primary;
        Unix.close dev;
        None
      )
    ) else (
      Unix.close dev;
      None
    )

let save_old (t : Resources.t) (x : Kms.Crtc.t) =
  let encoder_uses_crtc = function
    | { Kms.Encoder.crtc_id = Some cid; _ } -> cid = x.crtc_id
    | _ -> false
  in
  let encoders = List.filter encoder_uses_crtc t.encoders |> List.map (fun (x : Kms.Encoder.t) -> x.encoder_id) in
  let connector_uses_crtc = function
    | { Kms.Connector.encoder_id = Some eid; _ } -> List.mem eid encoders
    | _ -> false
  in
  let connectors =
    t.connectors
    |> List.filter connector_uses_crtc
    |> List.map (fun (c : Kms.Connector.t) -> c.connector_id)
  in
  let crtc = Kms.Crtc.get t.dev x.crtc_id in
  if crtc.mode = None then None
  else Some (crtc, connectors)

let reset_crtc (t : Resources.t) ((x : Kms.Crtc.t), (connectors : Kms.Connector.id list)) =
  let fb = x.fb_id in
  let pos = (x.x, x.y) in
  try
    Kms.Crtc.set t.dev x.crtc_id x.mode ?fb ~pos ~connectors
  with ex ->
    Fmt.epr "reset_crtc failed: %a@." Fmt.exn ex

(* Record the current graphics configuration, run the given function, and then put things back as they were.
   Also installs a signal handler so that Ctrl-C will restore things immediately (for emergencies). *)
let restoring_afterwards (t : Resources.t) fn =
  let old_sig = ref None in
  let old = List.filter_map (save_old t) t.crtcs in
  let cleanup () =
    Option.iter (fun h -> ignore (Sys.(signal sigint) h : Sys.signal_behavior)) !old_sig;
    old_sig := None;
    List.iter (reset_crtc t) old
  in
  let handle_ctrl_c (_ : int) = cleanup (); raise Sys.Break in
  old_sig := Some (Sys.(signal sigint) (Signal_handle handle_ctrl_c));
  Fun.protect ~finally:cleanup fn

(* Open the first suitable KMS device. *)
let with_device fn =
  let devices = Drm.Device.list () in
  match List.find_map open_device devices with
  | None -> Fmt.failwith "@[<v2>No suitable device found. get_devices returned:@,%a@]" (Fmt.Dump.list Drm.Device.Info.pp) devices
  | Some dev ->
    Drm.Client_cap.(set_exn atomic) dev true;
    fn (Resources.get dev)

let is_connected (x : Kms.Connector.t) = x.connection = Connected
