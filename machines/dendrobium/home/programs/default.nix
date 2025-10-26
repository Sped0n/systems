{
  imports = [
    ./git.nix
    ./neovim.nix
    ./ssh.nix
    ./zsh.nix
  ];

  programs.uv.enable = true;
  programs.aichat = {
    enable = true;
    model = "x-ai/grok-4-fast";
  };
}
