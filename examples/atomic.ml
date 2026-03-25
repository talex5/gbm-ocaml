(* Configure all currently-connected displays to show a test pattern for a few seconds.

   This needs to be run from a Linux text console (e.g. Ctrl-Alt-F2) as it
   needs to take control of the display hardware.

   This is similar to the example in libdrm-ocaml, but it displays a framebuffer allocated
   by GBM rather than a dumb-buffer. The advantage is that such a buffer can be used with
   e.g. Vulkan for accelerated rendering. *)

module K = Drm.Kms

let println fmt = Fmt.pr (fmt ^^ "@.")

let find_plane dev ~crtc_idx ~free_planes =
  let rec aux = function
    | [] -> Fmt.failwith "No suitable primary plane for CRTC with index %d" crtc_idx
    | x :: xs ->
      let plane = K.Plane.get dev x in
      if plane.possible_crtcs land (1 lsl crtc_idx) <> 0 then (
        let props = K.Plane.get_properties dev x in
        match K.Properties.Values.get_value props K.Plane.typ with
        | Some `Primary ->
          free_planes := List.filter ((<>) x) !free_planes;
          Some props
        | _ -> aux xs
      ) else aux xs
  in
  aux !free_planes

let show_test_page ~gbm ~free_planes (t : Resources.t) rq (c : K.Connector.t) =
  let obj = K.Connector.get_properties t.dev c.connector_id in
  match K.Properties.Values.get_value_exn obj K.Connector.crtc_id with
  | None -> Fmt.failwith "Connector %a has no CRTC" Drm.Id.pp c.connector_id
  | Some crtc_id ->
    println "Preparing settings for %a" K.Connector.pp_name c;
    let mode = List.hd c.modes in
    let size = (mode.hdisplay, mode.vdisplay) in
    let crtc_idx = Resources.crtc_index t crtc_id in
    let plane =
      match find_plane t.dev ~crtc_idx ~free_planes with
      | Some x -> x
      | None ->
        Fmt.failwith "No suitable primary plane for CRTC %a (with index %d)"
          Drm.Id.pp crtc_id
          crtc_idx
    in
    println "%a: Using plane %a" K.Connector.pp_name c Drm.Id.pp (K.Properties.object_id plane.metadata);
    let fb = Test_image.create t.dev size ~gbm ~plane in
    let ( .%{}<- ) obj prop value =
      K.Atomic_req.add_property rq obj.K.Properties.Values.metadata prop value
    in
    plane.%{ K.Plane.fb_id } <- Some fb;
    (* Source region on frame-buffer: *)
    plane.%{ K.Plane.src_x } <- Drm.Ufixed.of_int 0;
    plane.%{ K.Plane.src_y } <- Drm.Ufixed.of_int 0;
    plane.%{ K.Plane.src_w } <- Drm.Ufixed.of_int (fst size);
    plane.%{ K.Plane.src_h } <- Drm.Ufixed.of_int (snd size);
    (* Destination region on CRTC: *)
    plane.%{ K.Plane.crtc_x } <- 0;
    plane.%{ K.Plane.crtc_y } <- 0;
    plane.%{ K.Plane.crtc_w } <- fst size;
    plane.%{ K.Plane.crtc_h } <- snd size;
    ()

let () =
  try
    Utils.with_device @@ fun t ->
    let gbm = Gbm.Device.create t.dev in
    println "Using GBM backed %S" (Gbm.Device.get_backend_name gbm);
    let connected = List.filter Utils.is_connected t.connectors in
    println "Found %d connected connectors" (List.length connected);
    let free_planes = ref (K.Plane.list t.dev) in
    let rq = K.Atomic_req.create () in
    List.iter (show_test_page ~gbm ~free_planes t rq) connected;
    Utils.restoring_afterwards t @@ fun () ->
    println "Committing changes";
    K.Atomic_req.commit t.dev rq;
    println "Success!";
    Unix.sleep 2;
    println "Restoring old configuration"
  with Failure msg ->
    Fmt.epr "%s@." msg;
    exit 1
