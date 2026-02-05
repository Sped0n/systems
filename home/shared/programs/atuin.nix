{ pkgs-unstable, ... }:
{
  programs.atuin = {
    enable = true;
    package = pkgs-unstable.atuin;
    enableZshIntegration = false;
    settings = {
      auto_sync = true;
      sync_frequency = "1m";
      sync_address = "https://atuin.sped0n.com";
      style = "compact";
      inline_height = 17;
      invert = false;
      enter_accept = false;
    };
  };
}
