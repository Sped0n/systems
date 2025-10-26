{ libutils, pkgs-unstable, ... }:
{
  programs.yazi = {
    enable = true;
    package = pkgs-unstable.yazi;
    theme = builtins.fromTOML (
      builtins.readFile (libutils.fromRoot "/home/shared/config/yazi/theme.toml")
    );
  };
}
