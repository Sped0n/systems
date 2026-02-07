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
      history_filter = [
        "^cd(\\s|$)"
        "^ls(\\s|$)"
        "^exa(\\s|$)"
        "^rm(\\s|$)"
        "^(sudo\s+)?rm(\\s|$)"
        "^cat(\\s|$)"
        "^(sudo\s+)?cat(\\s|$)"
        "^bat(\\s|$)"
        "(?i)^clear(\\s|$)"
        "^open(\\s|$)"
        "pbcopy"
      ];
    };
  };
}
