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
      # General packages for development and system management
      just
      openssh
      wget
      curl
      nali

      # Encryption and security tools
      age
      gnupg

      # Text and terminal utilities
      du-dust
      fd
      fzf
      btop
      jq
      ripgrep
      tree
      less
      tokei
      tlrc
    ]);
}
