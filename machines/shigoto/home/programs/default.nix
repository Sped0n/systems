{
  imports = [
    ./git.nix
    ./ssh.nix
    ./neovim.nix
    ./trayscale.nix
  ];

  programs.aichat = {
    enable = true;
    model = "qwen/qwen3-235b-a22b-2507";
  };
}
