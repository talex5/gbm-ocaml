let ( !@ ) = Ctypes.( !@ )

module type FLAGS = sig
  type t

  val none : t
  val ( + ) : t -> t -> t
end

module Device = struct
  module F = C.Functions.Device

  type t = C.Types.Device.t Ctypes.ptr

  let create fd =
    match F.create fd with
    | Some x, _ -> x
    | None, errno -> Err.report errno "gbm_create" ""

  let destroy t = F.destroy t |> Err.ignore

  let get_format_modifier_plane_count t f m = F.get_format_modifier_plane_count t f m |> Err.ignore
  let get_backend_name t = F.get_backend_name t |> Err.ignore
  let is_format_supported t ~flags f = F.is_format_supported t f flags |> Err.ignore
end

module Bo = struct
  type t = C.Types.Bo.t Ctypes.ptr

  module Flags = C.Types.Bo_flags
  module Transfer_flags = C.Types.Bo_transfer_flags

  module F = C.Functions.Bo

  type plane = {
    fd : Unix.file_descr;
    stride : int;
    offset : int;
  }

  type import_data =
    | Fd of {
        width : int;
        height : int;
        format : Drm.Fourcc.t;
        modifier : Drm.Modifier.t;
        planes : plane list;
      }

  let import t ~flags = function
    | Fd { width; height; format; modifier; planes } ->
      let module D = C.Types.Import_fd_modifier_data in
      let data = Ctypes.make D.t in
      Ctypes.setf data D.width width;
      Ctypes.setf data D.height height;
      Ctypes.setf data D.format format;
      Ctypes.setf data D.modifier modifier;
      Ctypes.setf data D.num_fds (List.length planes);
      let fds = Ctypes.getf data D.fds in
      let strides = Ctypes.getf data D.strides in
      let offsets = Ctypes.getf data D.offsets in
      planes |> List.iteri (fun i { fd; stride; offset } ->
          Ctypes.CArray.set fds i fd;
          Ctypes.CArray.set strides i stride;
          Ctypes.CArray.set offsets i offset;
        );
      let buffer = Ctypes.to_voidp (Ctypes.addr data) in
      match F.import t C.Types.Import_type.fd_modifier buffer flags with
      | Some x, _ -> Ok x
      | None, errno -> Error (Err.error_of_errno errno)

  let create t ~flags ?modifiers ~format (width, height) =
    let retval, errno =
      match modifiers with
      | None -> F.create t width height format flags
      | Some modifiers ->
        let modifiers = Ctypes.CArray.of_list C.Types.Base_types.modifier modifiers in
        F.create_with_modifiers2
          t width height format
          modifiers.astart modifiers.alength
          flags
    in
    match retval with
    | Some x -> Ok x
    | None -> Error (Err.error_of_errno errno)

  let create_exn t ~flags ?modifiers ~format size =
    match create t ~format ?modifiers ~flags size with
    | Ok t -> t
    | Error error ->
      Fmt.failwith "@[<v2>gbm_bo_create failed (%s):@,format=%a@,size=%a@,modifiers=%a@,flags=0x%a@]"
        (Unix.error_message error)
        Drm.Fourcc.pp format
        Fmt.(Dump.pair int int) size
        Fmt.(Dump.option (Dump.list Drm.Modifier.pp)) modifiers
        Unsigned.UInt32.pp_hex flags

  let destroy t = F.destroy t |> Err.ignore

  (* Can't make a ctypes view for this for some reason
     (it inlines the definition of the union and C compiler rejects it) *)
  let make_handle name x =
    match Ctypes.getf x C.Types.Bo_handle.u32 |> Drm.Id.of_uint32_opt with
    | None -> Fmt.failwith "%s failed" name
    | Some x -> x

  let get_handle t =
    F.get_handle t |> Err.ignore |> make_handle "gbm_bo_get_handle"

  let get_handle_for_plane t i =
    F.get_handle_for_plane t i |> Err.ignore |> make_handle "gbm_bo_get_handle_for_plane"

  let get_offset t i = F.get_offset t i |> Err.ignore
  let get_stride_for_plane t i = F.get_stride_for_plane t i |> Err.ignore
  let get_modifier t = F.get_modifier t |> Err.ignore
  let get_plane_count t = F.get_plane_count t |> Err.ignore

  let get_width t = F.get_width t |> Err.ignore
  let get_height t = F.get_height t |> Err.ignore

  let get_fd t = F.get_fd t |> Err.ignore
  let get_fd_for_plane t i = F.get_fd_for_plane t i |> Err.ignore
  let get_bpp t = F.get_bpp t |> Err.ignore

  type map_data = F.map_data

  type ('a, 'b) mapping = {
    data : ('a, 'b, Bigarray.c_layout) Bigarray.Array2.t;
    stride : int;
    map_data : map_data;
  }

  let map (type a b) ~flags ~(kind:(a, b) Bigarray.kind) t (x, y, width, height) =
    let stride_out = Ctypes.(allocate C.Types.Base_types.int_uint32_t) 0 in
    let map_data_out = Ctypes.(allocate (ptr void)) Ctypes.null in
    let data : (a Ctypes.ptr) =
      let untyped =
        match F.map t x y width height flags stride_out map_data_out with
        | Some x, _ -> x
        | None, errno -> Err.report errno "gbm_bo_map" ""
      in
      match kind with
      | Int32 -> Ctypes.(from_voidp int32_t) untyped
      | Int8_unsigned -> Ctypes.(from_voidp int8_t) untyped
      | _ -> failwith "Unsupported Bigarray kind"
    in
    let stride = !@ stride_out in
    let map_data = !@ map_data_out in
    let real_width = stride / Bigarray.kind_size_in_bytes kind in
    let expected_bpp = Bigarray.kind_size_in_bytes kind * 8 in
    let actual_bpp = get_bpp t in
    if expected_bpp <> actual_bpp then
      Fmt.invalid_arg "Attempt to map with %d bpp array kind but %d bpp buffer!" expected_bpp actual_bpp;
    let data = Ctypes.(bigarray_of_ptr array2) (height, real_width) kind data in
    { data; stride; map_data }

  let unmap t mapping =
    F.unmap t mapping.map_data |> Err.ignore

  let with_map ~flags ~kind t rect f =
    let m = map ~flags ~kind t rect in
    match f m.data with
    | x -> unmap t m; x
    | exception ex ->
      let bt = Printexc.get_raw_backtrace () in
      unmap t m;
      Printexc.raise_with_backtrace ex bt
end
