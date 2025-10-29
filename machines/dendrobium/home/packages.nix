{
  determinate,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages = [
    (pkgs-unstable.nixos-anywhere.override {
      nix = determinate.inputs.nix.packages."${pkgs.stdenv.system}".default;
    })
  ];
}
