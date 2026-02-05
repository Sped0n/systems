{
  imports = [
    ./git.nix
    ./neovim.nix
    ./ssh.nix
  ];

  programs.uv.enable = true;
  programs.opencode.enable = true;
}
