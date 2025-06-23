{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages =
    (
      with pkgs;
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
          vim
          just
          tlrc
          openssh
          wget
          curl

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

          # Backup tools
          restic
        ]
    )
    ++ (
      with pkgs-unstable;
      # Language supports
        [
          # nix
          nixd
          alejandra

          # toml
          taplo

          # yaml
          yaml-language-server
          prettierd

          # json
          vscode-langservers-extracted

          # bash
          bash-language-server
          shellcheck
          shfmt

          # python
          ruff
          basedpyright

          # lua
          lua-language-server
          stylua
          selene
        ]
        ++
        # Others
        [
          nali
          yazi
        ]
    );
}
