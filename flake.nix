{
  description = "OCaml bindings for GBM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";
    libdrm-ocaml = {
      url = "github:talex5/libdrm-ocaml/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, libdrm-ocaml }:
  let eachSystem = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"]; in {
    packages = eachSystem(system:
    let pkgs = nixpkgs.legacyPackages.${system}; in {
      default = pkgs.callPackage (import ./default.nix) {
        libdrm-ocaml = libdrm-ocaml.packages.${system}.default;
      };
    });

    devShells = eachSystem(system:
    let pkgs = nixpkgs.legacyPackages.${system}; in {
      default = pkgs.mkShell {
        MERLIN = pkgs.ocamlPackages.merlin;
        OCPINDENT = pkgs.ocamlPackages.ocp-indent;

        nativeBuildInputs = self.outputs.packages.${system}.default.nativeBuildInputs;
        buildInputs = self.outputs.packages.${system}.default.buildInputs;
        propagatedBuildInputs = self.outputs.packages.${system}.default.propagatedBuildInputs;

        packages = with pkgs.ocamlPackages; [ ocp-indent utop odoc ];
        shellHook = ''exec ${pkgs.fish}/bin/fish'';
      };
    });
  };
}
