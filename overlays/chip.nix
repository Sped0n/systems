{ inputs, ... }:
final: prev: {
  zap-cli-bin = inputs.chip-host-tools.packages.${final.stdenv.hostPlatform.system}.zap-cli-bin;
  chip-host-tools =
    inputs.chip-host-tools.packages.${final.stdenv.hostPlatform.system}.chip-host-tools;
}
