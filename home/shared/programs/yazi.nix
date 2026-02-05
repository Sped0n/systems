{ functions, pkgs-unstable, ... }:
{
  programs.yazi = {
    enable = true;
    package = pkgs-unstable.yazi;
    theme = fromTOML (builtins.readFile (functions.fromRoot "/home/raw/yazi/theme.toml"));
  };
}
