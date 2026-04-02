{ ... }:
final: prev: {
  jina-cli = prev.callPackage ../packages/jina-cli.nix { };
}
