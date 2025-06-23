{...}: {
  imports = [
    ../../../shared/programs

    ./gnome.nix
    ./zsh.nix
    ./ghostty.nix
  ];

  programs.uv.enable = true;
}
