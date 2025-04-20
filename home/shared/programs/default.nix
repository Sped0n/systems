{...}: {
  imports = [
    ./zsh.nix
    ./starship.nix
    ./neovim.nix
    ./git.nix
    ./ssh.nix
    ./zellij.nix
    ./fastfetch.nix
  ];

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "base16";
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = ["--cmd cd" "--hook pwd"];
  };

  programs.atuin = {
    enable = true;
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

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig = {
      settings = {
        disable_hints = ["python_multi"];
        trusted_config_paths = ["~"];
      };
    };
  };
}
