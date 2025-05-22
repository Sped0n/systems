{
  lib,
  pkgs,
  ...
}: {
  programs.zsh = {
    initContent = lib.mkMerge [
      (lib.mkOrder 1550 ''
        alias pbcopy='xclip -selection clipboard'
        alias pbpaste='xclip -selection clipboard -o'
      '')
    ];
  };

  home.packages = [pkgs.xclip];
}
