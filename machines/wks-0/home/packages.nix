{
  determinate,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages = with pkgs-unstable; [
    (nixos-anywhere.override {
      nix = determinate.inputs.nix.packages."${pkgs.stdenv.system}".default;
    })
    gh
  ];
}
