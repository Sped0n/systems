{pkgs-unstable, ...}: {
  imports = [
    ./zsh.nix
    ./starship.nix
    ./neovim.nix
    ./git.nix
    ./gitui.nix
    ./ssh.nix
    ./fastfetch.nix
    ./ghostty.nix
    ./uv.nix
    ./direnv.nix
    ./codegpt.nix
    ./tmux.nix
  ];

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "ansi";
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = ["--cmd cd" "--hook pwd"];
  };

  programs.atuin = {
    enable = true;
    package = pkgs-unstable.atuin;
    enableZshIntegration = false;
    settings = {
      auto_sync = true;
      sync_frequency = "10m";
      sync_address = "http://tennousei:10004";
      style = "compact";
      inline_height = 10;
      invert = false;
      enter_accept = false;
    };
  };
}
