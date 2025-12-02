{ pkgs, vars, ... }:
{
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];
  users.users.${vars.username}.shell = pkgs.zsh;
}
