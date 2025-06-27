{
  imports = [
    ./ssh.nix
    ./neovim.nix
  ];

  programs.uv.enable = true;
}
