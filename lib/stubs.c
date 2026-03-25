#include <caml/mlvalues.h>
#include <caml/unixsupport.h>

value caml_gbm_unix_error_of_code(value v_errno) { return caml_unix_error_of_code(Int_val(v_errno)); }
