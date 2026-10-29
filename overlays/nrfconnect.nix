{ ... }:
final: prev: {
  nrfconnect = final.callPackage ../packages/nrfconnect.nix { };
}
