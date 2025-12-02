{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      coreutils
      findutils
      diffutils
      gnused
      gnugrep
      gawk
      gnutar
      gzip
      bzip2
      xz
      gnumake
      patch
      zip
      unzip
      inetutils
      tcptraceroute
    ])
    ++ (with pkgs-unstable; [
      just
      openssh
      wget
      curl
      nali

      age
      gnupg

      dust
      fd
      fzf
      btop
      jq
      ripgrep
      tree
      less
      tokei
      tlrc

      croc
    ]);
}
