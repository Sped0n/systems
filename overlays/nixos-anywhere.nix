{ inputs, ... }:
final: prev: {
  nixos-anywhere = prev.nixos-anywhere.override {
    nix = inputs.determinate.inputs.nix.packages."${prev.stdenv.system}".default;
  };
}
