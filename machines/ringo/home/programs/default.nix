{
  imports = [
    ./git.nix
    ./neovim.nix
    ./ssh.nix
  ];

  programs.uv.enable = true;
  programs.aichat = {
    enable = true;
    model = "deepseek/deepseek-chat-v3.1";
  };
}
