{
  pkgs,
  systemConfig,
  ...
}:
{
  nix.gc = {
    automatic = true;
    dates = if pkgs.stdenv.isLinux then systemConfig.nix.gc.dates else "monthly";
    options = if pkgs.stdenv.isLinux then systemConfig.nix.gc.options else "--delete-older-than 30d";
  };
}
