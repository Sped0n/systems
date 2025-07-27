{
  imports = [
    ./git.nix
    ./neovim.nix
    ./ssh.nix
  ];

  programs.uv.enable = true;
  programs.codegpt = {
    enable = true;
    model = "moonshotai/kimi-k2";
  };
}
