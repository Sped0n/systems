{pkgs, ...}: {
  home.packages = with pkgs;
  # Core
    [
      gcc
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
    ]
    ++ [
      # General packages for development and system management
      just
      openssh
      wget
      curl
      nali
      hyperfine
      ast-grep
      act
      bfg-repo-cleaner
      yek

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
      yazi
      tokei
      tlrc
    ];
}
