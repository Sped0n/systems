{ ... }:
final: prev: {
  zap-cli-bin = final.callPackage ../packages/zap-cli-bin.nix { };

  chip-host-tools = final.callPackage ../packages/chip-host-tools.nix {
    callPackage = final.callPackage;
  };
}
