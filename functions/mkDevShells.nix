{
  lib,
  pkgsFor,
  pkgsUnstableFor,
}:
let
  supportedSystems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];
in
lib.genAttrs supportedSystems (
  system:
  let
    pkgs = pkgsFor system;
    pkgs-unstable = pkgsUnstableFor system;
  in
  {
    default = pkgs.mkShellNoCC {
      packages =
        (with pkgs; [
          nodejs_24
          pnpm_11
          (python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ]))
        ])
        ++ (with pkgs-unstable; [
          nixfmt
          prek
          ruff
          actionlint
        ]);
    };
  }
)
