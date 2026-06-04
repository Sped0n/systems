{ pkgs, ... }:
{
  programs.zsh.shellAliases = {
    pbcopy = "${pkgs.wl-clipboard}/bin/wl-copy --trim-newline";
    pbpaste = "${pkgs.wl-clipboard}/bin/wl-paste --no-newline";
    open = "xdg-open";
  };

  home.packages = [ pkgs.wl-clipboard ];
}
