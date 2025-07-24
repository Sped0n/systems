{
  imports = [
    ./ssh.nix
    ./neovim.nix
  ];

  programs.uv.enable = true;
  programs.codegpt = {
    enable = true;
    model = "moonshotai/kimi-k2";
  };
}
