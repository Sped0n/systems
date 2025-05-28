{...}: {
  imports = [
    ../../../shared/programs

    ./ghostty.nix
    ./zsh.nix
  ];

  programs.uv.enable = true;
}
