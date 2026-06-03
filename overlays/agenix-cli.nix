{ inputs, ... }:
final: prev: {
  agenix-cli = inputs.agenix.packages."${prev.stdenv.system}".default;
}
