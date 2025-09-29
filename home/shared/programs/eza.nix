{ ... }:
{
  programs = {
    eza = {
      enable = true;
      enableZshIntegration = true;
    };
    zsh.shellAliases = {
      "exl" = "exa -l";
      "exaa" = "exa -a";
    };
  };
}
