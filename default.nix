{ pkgs, pkgconf, libffi, libdrm-ocaml, ocamlPackages, libgbm }:

ocamlPackages.buildDunePackage {
  pname = "gbm";
  version = "0.1";

  src = ./.;

  nativeBuildInputs = [ pkgconf ];
  buildInputs = [ ocamlPackages.dune-configurator ];
  propagatedBuildInputs = [ libgbm libdrm-ocaml ] ++ (with ocamlPackages; [ ctypes-foreign ctypes fmt ]);
}
