{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      coreutils
      findutils
      diffutils
      inetutils
      gnused
      gnugrep
      gawk
      gnutar
      gnumake
      gnupg
      patch
      gzip
      bzip2
      xz
      zip
      unzip

      age
      fzf
      ripgrep
      fd
      dust
      tree
      jq
      less
      wget
      curl
      aria2
    ])
    ++ (with pkgs-unstable; [
      just
      btop
      tokei
      tlrc

      nali
      nexttrace

      croc
    ]);
}
