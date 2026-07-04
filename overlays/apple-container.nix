{ ... }:
final: prev: {
  apple-container = prev.callPackage ../packages/apple-container.nix { };
}
