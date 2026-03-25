external caml_unix_error_of_code : int -> Unix.error = "caml_gbm_unix_error_of_code"

let error_of_errno errno =
  caml_unix_error_of_code (Signed.SInt.to_int errno)

let report errno fn arg =
  raise (Unix.Unix_error (error_of_errno errno, fn, arg))

(* For functions that don't set errno *)
let ignore (x, (_ : Signed.SInt.t)) = x
