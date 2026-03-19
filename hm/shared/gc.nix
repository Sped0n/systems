{
  config,
  lib,
  pkgs,
  systemConfig ? null,
  ...
}:
{
  config = lib.mkIf (!lib.attrByPath [ "services" "standalone" "enable" ] false config) {
    nix.gc = {
      automatic = true;
      dates =
        if pkgs.stdenv.isLinux && systemConfig != null then systemConfig.nix.gc.dates else "monthly";
      options =
        if pkgs.stdenv.isLinux && systemConfig != null then
          systemConfig.nix.gc.options
        else
          "--delete-older-than 30d";
    };
  };
}
