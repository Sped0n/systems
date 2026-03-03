{ inputs, ... }:
final: prev: {
  agenix-cli = inputs.agenix.packages."${prev.stdenv.system}".default.override {
    nix = inputs.determinate.inputs.nix.packages."${prev.stdenv.system}".default;
  };
}
