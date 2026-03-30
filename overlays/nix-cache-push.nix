{ inputs, ... }:
final: prev: {
  nix-cache-push = inputs.nix-cache-push.packages."${prev.stdenv.system}".default;
}
