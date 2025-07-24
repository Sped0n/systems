{
  imports = [
    ./git.nix
    ./ssh.nix
    ./neovim.nix
    ./trayscale.nix
  ];

  programs.codegpt = {
    enable = true;
    model = "moonshotai/kimi-k2";
  };
}
