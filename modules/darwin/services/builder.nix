{
  lib,
  pkgs-unstable,
  ...
}:
{
  nix.linux-builder = {
    package = pkgs-unstable.darwin.linux-builder-vz;
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    supportedFeatures = [
      "benchmark"
      "big-parallel"
    ];
    workingDirectory = "/var/lib/linux-builder-vz";

    # The stable nix-darwin module otherwise supplies stable host packages without vzvm.
    config.virtualisation.host.pkgs = lib.mkForce pkgs-unstable;
  };
}
