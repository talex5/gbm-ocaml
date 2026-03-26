(** OCaml bindings for {{: https://en.wikipedia.org/wiki/Mesa_(computer_graphics)#Generic_Buffer_Management } GBM}.

    This library can be used to allocate GPU memory for display with KMS and/or rendering with Vulkan.

    Warning: this is a thin wrapper around the C API and does not protect you from memory leaks, use-after-free, etc. *)

module type FLAGS = sig
  type t

  val none : t

  val ( + ) : t -> t -> t
  (** Union (logical OR) *)
end

module rec Device : sig
  type t = [ `Gbm_device ] Ctypes.structure Ctypes.ptr

  val create : Unix.file_descr -> t
  (** Create a gbm device for allocating buffers.

      The file descriptor passed in is used by the backend to communicate with
      platform for allocating the memory. For allocations using DRI this would be
      the file descriptor returned when opening a device such as "/dev/dri/card0".

      The resources associated with the device should be freed with
      {!destroy} when it is no longer needed. *)

  val destroy : t -> unit
  (** Destroy the gbm device and free all resources associated with it.

      Prior to calling this function all buffers and surfaces created with the
      gbm device need to be destroyed. *)

  val get_backend_name : t -> string

  val is_format_supported : t -> flags:Bo.Flags.t -> Drm.Fourcc.t -> bool
  (** Test if a format is supported for a given set of usage flags. *)

  val get_format_modifier_plane_count : t -> Drm.Fourcc.t -> Drm.Modifier.t -> int
  (** Get the number of planes that are required for a given format+modifier. *)
end

and Bo : sig
  type t = [ `Gbm_bo ] Ctypes.structure Ctypes.ptr

  module Flags : sig
    include FLAGS

    val use_scanout : t
    (** Buffer is going to be presented to the screen using an API such as KMS. *)

    val use_cursor : t
    (** Buffer is going to be used as cursor. *)

    val use_rendering : t
    (** Buffer is to be used for rendering - for example it is going to be used
        as the storage for a colour buffer. *)

    val use_write : t
    (** Buffer can be used for writing. This is guaranteed to work
        with {!use_cursor}, but may not work for other combinations. *)

    val use_linear : t
    (** Buffer is linear, i.e. not tiled. *)

    val use_protected : t
    (** Buffer is protected, i.e. encrypted and not readable by CPU or any
        other non-secure / non-trusted components nor by non-trusted OpenGL,
        OpenCL, and Vulkan applications. *)

    val use_front_rendering : t
    (** The buffer will be used for front buffer rendering. On some
        platforms this may (for example) disable framebuffer compression
        to avoid problems with compression flags data being out of sync
        with pixel data. *)

    val fixed_compression_default : t
    (** Allow the driver to select fixed-rate compression parameters. *)

    val fixed_compression_1bpc : t
    (** Fixed-rate compression: at least 1bpc, less than 2bpc. *)

    val fixed_compression_2bpc : t
    val fixed_compression_3bpc : t
    val fixed_compression_4bpc : t
    val fixed_compression_5bpc : t
    val fixed_compression_6bpc : t
    val fixed_compression_7bpc : t
    val fixed_compression_8bpc : t
    val fixed_compression_9bpc : t
    val fixed_compression_10bpc : t
    val fixed_compression_11bpc : t

    val fixed_compression_12bpc : t
    (**  Fixed-rate compression: at least 12bpc, no maximum rate *)
  end

  module Transfer_flags : sig
    (** Flags to indicate the type of mapping for the buffer - these are
        passed into {!Bo.map}. The caller must set the union of all the
        flags that are appropriate.

        These flags are independent of the "Flags.use_*" creation flags. However,
        mapping the buffer may require copying to/from a staging buffer. *)

    include FLAGS

    val read : t
    (** Buffer contents read back (or accessed directly) at transfer create time. *)

    val write : t
    (** Buffer contents will be written back at unmap time (or modified as a result of being accessed directly). *)

    val read_write : t
    (** Read/modify/write *)
  end

  val create :
    Device.t ->
    flags:Flags.t ->
    ?modifiers:Drm.Modifier.t list ->
    format:Drm.Fourcc.t ->
    int * int -> (t, Unix.error) result
  (** Allocate a buffer object for the given dimensions.

      @return A newly allocated buffer that should be freed with {!destroy} when no
      longer needed. *)

  val create_exn :
    Device.t ->
    flags:Flags.t ->
    ?modifiers:Drm.Modifier.t list ->
    format:Drm.Fourcc.t ->
    int * int -> t
  (** Like [create], but raises a somewhat user-friendly exception on error. *)

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

  val import :
    Device.t ->
    flags:Flags.t ->
    import_data ->
    (t, Unix.error) result
  (** Create a GBM buffer object from a foreign object.

      This function imports a foreign object and creates a new GBM BO for it.
      This enables using the foreign object with a display API such as KMS.

      The GBM BO shares the underlying pixels but its life-time is independent
      of the foreign object.

      @return A newly allocated buffer object that should be freed with
      {!destroy} when no longer needed. *)

  val destroy : t -> unit

  val get_modifier : t -> Drm.Modifier.t
  (**  Get the chosen modifier for the buffer object

       This function returns the modifier that was chosen for the object. These
       properties may be generic, or platform/implementation dependent. *)

  val get_width : t -> int
  val get_height : t -> int

  val get_plane_count : t -> int
  (** Get the number of planes for the given BO. *)

  val get_handle : t -> Drm.Buffer.id
  (** Get the handle of the buffer object. *)

  val get_handle_for_plane : t -> int -> Drm.Buffer.id
  (** Get the handle for the specified plane of the buffer object

      This function gets the handle for any plane associated with the BO. When
      dealing with multi-planar formats, or formats which might have implicit
      planes based on different underlying hardware it is necessary for the client
      to be able to get this information to pass to the DRM. *)

  val get_offset : t -> int -> int
  (** Get the offset for the data of the specified plane.

      Extra planes, and even the first plane, may have an offset from the start of
      the buffer object. This function will provide the offset for the given plane
      to be used in various KMS APIs. *)

  val get_stride_for_plane : t -> int -> int

  val get_fd : t -> Unix.file_descr
  (** Get a DMA-BUF file descriptor for the buffer object

      This function creates a DMA-BUF (also known as PRIME) file descriptor
      handle for the buffer object. Each call to {!get_fd} returns a new
      file descriptor and the caller is responsible for closing the file
      descriptor. *)

  val get_fd_for_plane : t -> int -> Unix.file_descr
  (** Get a DMA-BUF file descriptor for the specified plane of the buffer object

      This function creates a DMA-BUF (also known as PRIME) file descriptor
      handle for the specified plane of the buffer object. Each call to
      {!get_fd_for_plane} returns a new file descriptor and the caller is
      responsible for closing the file descriptor. *)

  val get_bpp : t -> int
  (** Get the bit-per-pixel of the buffer object's format.

      Note; The 'in-memory pixel' concept makes no sense for YUV formats
      (pixels are the result of the combination of multiple memory sources:
      Y, Cb & Cr; usually these are even in separate buffers), so YUV
      formats are not supported by this function. *)

  type map_data
  (** Opaque ptr for a mapped region. *)

  type ('a, 'b) mapping = {
    data : ('a, 'b, Bigarray.c_layout) Bigarray.Array2.t;
    stride : int;
    map_data : map_data;
  }

  val map :
    flags:Transfer_flags.t ->
    kind:('a, 'b) Bigarray.kind ->
    t ->
    int * int * int * int -> ('a, 'b) mapping
  (** [map ~flags ~kind (x, y, width, height)] map a region of a GBM buffer object for CPU access.

      This function maps a region of a GBM BO for CPU read and/or write access.

      The mapping exposes a linear view of the buffer object even if the buffer
      has a non-linear modifier.

      This function may require intermediate buffer copies (ie. it may be slow).
 
      [(x, y)] is the starting position of the mapped region for
      the buffer (top-left origin).

      @param kind Only [Int32] or [Int8_unsigned] are currently supported. *)

  val unmap : t -> _ mapping -> unit
  (**  Unmap a previously mapped region of a GBM buffer object

       This function unmaps a region of a GBM bo for CPU read and/or write
       access. *)

  val with_map :
    flags:Transfer_flags.t ->
    kind:('a, 'b) Bigarray.kind ->
    t ->
    int * int * int * int ->
    (('a, 'b, Bigarray.c_layout) Bigarray.Array2.t -> 'c) ->
    'c
  (** Convenience function to {!map} a region, use it, and then {!unmap} it again. *)
end
