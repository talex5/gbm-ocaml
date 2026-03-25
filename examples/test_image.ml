module K = Drm.Kms

let test_pattern (x, y) =
  Int32.of_int @@
  (x land 0xff) lor
  ((y land 0xff) lsl 8) lor
  (((x lsr 8) lor (y lsr 8)) lsl 18)

let write_pattern f arr =
  let rows = Bigarray.Array2.dim1 arr in
  let cols = Bigarray.Array2.dim2 arr in
  for row = 0 to rows - 1 do
    for col = 0 to cols - 1 do
      arr.{row, col} <- f (row, col)
    done;
  done

let tee f x = f x; x

(* Find compatible modifiers for [pixel_format].
   We also restrict to one plane, as otherwise we wouldn't know how to write to it. *)
let get_modifiers ~pixel_format ~gbm dev blob_id =
  K.Plane.get_in_formats dev blob_id
  |> List.filter_map (fun (f, m) -> if f = pixel_format then Some m else None)
  |> tee (Fmt.pr "Permitted modifiers %a@." (Fmt.Dump.list Drm.Modifier.pp))
  |> List.filter (fun m -> Gbm.Device.get_format_modifier_plane_count gbm pixel_format m = 1)
  |> tee (Fmt.pr "Filtered modifiers %a (single-plane only)@." (Fmt.Dump.list Drm.Modifier.pp))

(* Allocate a GBM buffer to display on [plane] and fill it with a test pattern. *)
let create ?(pattern=test_pattern) ?(pixel_format=Drm.Fourcc.xr24) ~plane ~gbm dev size =
  let in_formats = K.Properties.Values.get_value plane K.Plane.in_formats in
  (* If [in_formats = None] then this device doesn't support modifiers. *)
  let modifiers = Option.map (get_modifiers ~pixel_format ~gbm dev) in_formats in
  let buffer, modifier =
    let flags = Gbm.Bo.Flags.(use_scanout + use_write) in
    let bo = Gbm.Bo.create_exn gbm ~format:pixel_format ?modifiers ~flags size in
    let handle = Gbm.Bo.get_handle bo in
    let offset = Gbm.Bo.get_offset bo 0 in
    let pitch = Gbm.Bo.get_stride_for_plane bo 0 in
    let plane_count = Gbm.Bo.get_plane_count bo in
    let modifier =
      if modifiers = None then (
        Fmt.pr "(device does not support modifiers)@.";
        None
      ) else (
        let modifier = Gbm.Bo.get_modifier bo in
        Fmt.pr "GBM selected modifier %a (#planes=%d)@." Drm.Modifier.pp modifier plane_count;
        Some modifier
      )
    in
    assert (plane_count = 1);
    Gbm.Bo.with_map bo (0, 0, fst size, snd size)
      ~flags:Gbm.Bo.Transfer_flags.write
      ~kind:Int32
      (write_pattern pattern);
    K.Fb.Plane.v handle ~pitch ~offset, modifier
  in
  let planes = [K.Fb.Plane.v buffer.handle ~pitch:buffer.pitch] in
  K.Fb.add dev ~size ~planes ~pixel_format ?modifier
