{pkgs-unstable, ...}: {
  imports = [
    ../../../home/shared/packages.nix
  ];

  home.packages = (
    # Desktop Application
    with pkgs-unstable;
      [
        brave
        bitwarden-desktop
      ]
      ++
      # Languages supports
      [
        # python
        uv
        ruff
        basedpyright

        # rust
        rustup

        # c/cpp
        clang-tools
        neocmakelsp

        # bash
        bash-language-server
        shellcheck
        shfmt
      ]
  );
}
