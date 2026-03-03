{
  pkgs,
  lib,
  ...
}:
{
  # source: https://github.com/nix-community/srvos/blob/main/nixos/mixins/terminfo.nix
  environment.systemPackages = [
    pkgs.wezterm.terminfo
    (pkgs.runCommand "ghostty-terminfo"
      {
        nativeBuildInputs = [ pkgs._7zz ];
      }
      ''
        7zz -snld x ${pkgs.ghostty-bin.src}
        mkdir -p $out/share/terminfo/{g,x}
        cp -r Ghostty.app/Contents/Resources/terminfo/67/ghostty $out/share/terminfo/g
        cp -r Ghostty.app/Contents/Resources/terminfo/78/xterm-ghostty $out/share/terminfo/x
      ''
    )
  ]
  ++ lib.optionals (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform) [
    pkgs.foot.terminfo
    pkgs.kitty.terminfo
    pkgs.termite.terminfo
  ];
}
