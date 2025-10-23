{
  imports = [
    ./git.nix
    ./ssh.nix
    ./neovim.nix
    ./trayscale.nix
  ];

  programs.aichat = {
    enable = true;
    model = "deepseek/deepseek-chat-v3.1";
  };
}
