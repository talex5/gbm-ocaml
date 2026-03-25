(lang dune 3.18)
(name gbm)
(using ctypes 0.3)
(formatting disabled)
(generate_opam_files true)

(source (github talex5/gbm-ocaml))
(license ISC)
(authors "Thomas Leonard")
(maintainers "Thomas Leonard")
(documentation "https://talex5.github.io/gbm-ocaml/")

(package
 (name gbm)
 (synopsis "OCaml bindings for gbm")
 (description "Generic Buffer Management (GBM) is an API that provides a mechanism for allocating buffers for graphics rendering tied to Mesa.")
 (depends
  (ocaml (>= 5.3.0))
  (ctypes (>= 0.23.0))
  (ctypes-foreign (>= 0.23.0))
  (fmt (>= 0.8.9))))
