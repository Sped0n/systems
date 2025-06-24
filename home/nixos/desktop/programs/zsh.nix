{pkgs, ...}: {
  programs.zsh = {
    shellAliases = {
      pbcopy = "${pkgs.wl-clipboard}/bin/wl-copy";
      pbpaste = "${pkgs.wl-clipboard}/bin/wl-paste";
      open = "xdg-open";
    };
  };

  home.packages = [pkgs.wl-clipboard];
}
