{ ... }:
{
  # Keep the Nix-aware sudo wrapper defined in zsh.nix.
  programs.ghostty.settings.shell-integration-features = "cursor,no-sudo,title,ssh-env,ssh-terminfo,path";
}
