{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      nixos-rebuild-ng

      llm-agents.cursor-agent
      hunk
    ])
    ++ (with pkgs-unstable; [
      popsicle
    ]);
}
