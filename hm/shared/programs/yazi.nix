{ functions, pkgs-unstable, ... }:
{
  programs.yazi = {
    enable = true;
    package = pkgs-unstable.yazi;
    theme = fromTOML (builtins.readFile (functions.fromRoot "/hm/raw/yazi/theme.toml"));
  };
}
