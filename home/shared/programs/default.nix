{pkgs-unstable, ...}: {
  imports = [
    ./zsh.nix
    ./starship.nix
    ./neovim.nix
    ./git.nix
    ./ssh.nix
    ./zellij.nix
    ./mise.nix
    ./fastfetch.nix
    ./ghostty.nix
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
      sync_frequency = "1d";
      sync_address = "https://atuin.sped0n.com";
      style = "compact";
      inline_height = 10;
      invert = false;
      enter_accept = false;
    };
  };
}
