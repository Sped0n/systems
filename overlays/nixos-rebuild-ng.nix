{ inputs, ... }:
final: prev: {
  nixos-rebuild-ng = prev.nixos-rebuild-ng.override {
    nix = inputs.determinate.inputs.nix.packages."${prev.stdenv.system}".default;
  };
}
