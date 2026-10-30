{ ... }:
final: prev: {
  docker-seccomp = prev.callPackage ../packages/docker-seccomp.nix { };
}
