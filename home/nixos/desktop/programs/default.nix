{...}: {
  imports = [
    ../../../shared/programs

    ./gnome.nix
    ./zsh.nix
    ./ghostty.nix
    ./albert.nix
  ];

  programs.uv.enable = true;
}
