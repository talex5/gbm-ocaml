open Ctypes

module Types (F : Ctypes.TYPE) = struct
  open F

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
end
