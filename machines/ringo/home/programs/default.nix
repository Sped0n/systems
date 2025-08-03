{
  imports = [
    ./git.nix
    ./neovim.nix
    ./ssh.nix
  ];

  programs.uv.enable = true;
  programs.aichat = {
    enable = true;
    model = "qwen/qwen3-235b-a22b-2507";
  };
}
