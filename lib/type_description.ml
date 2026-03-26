open Ctypes

module Types (F : Ctypes.TYPE) = struct
  open F

  module Base_types = struct
    let int_of_unix (fd : Unix.file_descr) : int = Obj.magic fd
    let unix_of_int (fd : int) : Unix.file_descr = assert (fd >= 0); Obj.magic fd

    let fd = view ~read:unix_of_int ~write:int_of_unix int

    let drm_format = view uint32_t ~read:Drm.Fourcc.of_uint32 ~write:Drm.Fourcc.to_uint32
    let modifier = view uint64_t ~read:Drm.Modifier.of_uint64 ~write:Drm.Modifier.to_uint64

    let int_uint32_t = view ~read:Unsigned.UInt32.to_int ~write:Unsigned.UInt32.of_int uint32_t
    let int_uint = view ~read:Unsigned.UInt.to_int ~write:Unsigned.UInt.of_int uint

    let bool_int = view ~read:((<>) 0) ~write:Bool.to_int int
  end

  open Base_types

  module Device = struct
    type t = [`Gbm_device] structure
    let t : t typ = structure "gbm_device"
  end

  module Bo = struct
    type t = [`Gbm_bo] structure
    let t : t typ = structure "gbm_bo"
  end

  module Bo_flags = struct
    type t = Unsigned.UInt32.t
    let t = uint32_t

    let v name = constant name uint32_t

    let ( + ) = Unsigned.UInt32.logor
    let none = Unsigned.UInt32.zero

    let use_scanout = v "GBM_BO_USE_SCANOUT"
    let use_cursor = v "GBM_BO_USE_CURSOR"
    let use_rendering = v "GBM_BO_USE_RENDERING"
    let use_write = v "GBM_BO_USE_WRITE"
    let use_linear = v "GBM_BO_USE_LINEAR"
    let use_protected = v "GBM_BO_USE_PROTECTED"
    let use_front_rendering = v "GBM_BO_USE_FRONT_RENDERING"
    let fixed_compression_default = v "GBM_BO_FIXED_COMPRESSION_DEFAULT"
    let fixed_compression_1bpc = v "GBM_BO_FIXED_COMPRESSION_1BPC"
    let fixed_compression_2bpc = v "GBM_BO_FIXED_COMPRESSION_2BPC"
    let fixed_compression_3bpc = v "GBM_BO_FIXED_COMPRESSION_3BPC"
    let fixed_compression_4bpc = v "GBM_BO_FIXED_COMPRESSION_4BPC"
    let fixed_compression_5bpc = v "GBM_BO_FIXED_COMPRESSION_5BPC"
    let fixed_compression_6bpc = v "GBM_BO_FIXED_COMPRESSION_6BPC"
    let fixed_compression_7bpc = v "GBM_BO_FIXED_COMPRESSION_7BPC"
    let fixed_compression_8bpc = v "GBM_BO_FIXED_COMPRESSION_8BPC"
    let fixed_compression_9bpc = v "GBM_BO_FIXED_COMPRESSION_9BPC"
    let fixed_compression_10bpc = v "GBM_BO_FIXED_COMPRESSION_10BPC"
    let fixed_compression_11bpc = v "GBM_BO_FIXED_COMPRESSION_11BPC"
    let fixed_compression_12bpc = v "GBM_BO_FIXED_COMPRESSION_12BPC"
  end

  module Bo_transfer_flags = struct
    type t = Unsigned.UInt32.t

    let v name = constant name uint32_t

    let ( + ) = Unsigned.UInt32.logor
    let none = Unsigned.UInt32.zero

    let read = v "GBM_BO_TRANSFER_READ"
    let write = v "GBM_BO_TRANSFER_WRITE"
    let read_write = v "GBM_BO_TRANSFER_READ_WRITE"
  end

  module Bo_handle = struct
    type t = [`Gbm_bo_handle] union
    let t : t typ = union "gbm_bo_handle"

    let ptr = field t "ptr" (ptr void)
    let s32 = field t "s32" int32_t
    let u32 = field t "u32" uint32_t
    let s64 = field t "s64" int64_t
    let u64 = field t "u64" uint64_t

    let () = seal t
  end

  module Import_type = struct
    let v name = constant name uint32_t

    let wl_buffer = v "GBM_BO_IMPORT_WL_BUFFER"
    let egl_image = v "GBM_BO_IMPORT_EGL_IMAGE"
    let fd = v "GBM_BO_IMPORT_FD"
    let fd_modifier = v "GBM_BO_IMPORT_FD_MODIFIER"
  end

  module Import_fd_modifier_data = struct
    type t = [`Gbm_import_fd_modifier_data] structure
    let t : t typ = structure "gbm_import_fd_modifier_data"

    let max_planes = 4

    let width = field t "width" int_uint32_t
    let height = field t "height" int_uint32_t
    let format = field t "format" drm_format
    let num_fds = field t "num_fds" int_uint32_t

    let fds = field t "fds" (array max_planes fd)
    let strides = field t "strides" (array max_planes int)
    let offsets = field t "offsets" (array max_planes int)

    let modifier = field t "modifier" modifier

    let () = seal t
  end

end
