{ ... }:
final: prev: {
  espressif-udev = final.callPackage ../packages/espressif-udev.nix { };
}
