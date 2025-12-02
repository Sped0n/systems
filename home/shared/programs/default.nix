{ pkgs-unstable, ... }:
{
  imports = [
    ./aichat.nix
    ./aicommit.nix
    ./delta.nix
    ./direnv.nix
    ./eza.nix
    ./fastfetch.nix
    ./ghostty.nix
    ./git.nix
    ./neovim.nix
    ./ssh.nix
    ./starship.nix
    ./tmux.nix
    ./uv.nix
    ./yazi.nix
    ./zsh.nix
  ];

  programs.bat = {
    enable = true;
    config = {
      theme = "ansi";
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [
      "--cmd cd"
      "--hook pwd"
    ];
  };

  programs.atuin = {
    enable = true;
    package = pkgs-unstable.atuin;
    enableZshIntegration = false;
    settings = {
      auto_sync = true;
      sync_frequency = "1m";
      sync_address = "https://atuin.sped0n.com";
      style = "compact";
      inline_height = 10;
      invert = false;
      enter_accept = false;
    };
  };
}
