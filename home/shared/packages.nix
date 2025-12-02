{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      # Core
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
    ])
    ++ (with pkgs-unstable; [
      # general packages for development and system management
      just
      openssh
      wget
      curl
      nali

      # encryption and security tools
      age
      gnupg

      # text and terminal utilities
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

      # file transfer and synchronization
      croc
    ]);
}
