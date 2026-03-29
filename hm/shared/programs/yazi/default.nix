{ pkgs-unstable, ... }:
{
  programs.yazi = {
    enable = true;
    package = pkgs-unstable.yazi;
    theme = fromTOML (builtins.readFile ./theme.toml);
  };
}
