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
        "^export\\s+.*[A-Z_]*(KEY|TOKEN|SECRET|PASSWORD|AUTH)[A-Z_]*="

        "^ls(\\s|$)"
        "^exa(\\s|$)"
        "^(sudo\s+)?rm(\\s|$)"
        "^(sudo\s+)?cat(\\s|$)"
        "^(sudo\s+)?bat(\\s|$)"
        "(?i)^clear(\\s|$)"
        "^open(\\s|$)"
        "^ocommit(\\s|$)"
        "^nvim\\s*$"
        "^tldr\\s+"
        "^atuin\\s+key\\s*$"

        "^git\\s+(status|st|log|show)\\s*$"
        "^glo(\\s|$)"
        "^git\\s+rebase(\\s+.*)?\\s(-i|--interactive)(\\s|$)"
      ];
    };
  };
}
