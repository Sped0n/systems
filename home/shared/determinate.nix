{
  determinate,
  lib,
  pkgs,
  ...
}:
{
  nix.package = lib.mkForce determinate.inputs.nix.packages."${pkgs.stdenv.system}".default;
}
