{ pkgs, pkgs-unstable, ... }:
{
  home.packages =
    (with pkgs; [
      nixos-rebuild-ng

      llm-agents.cursor-agent
    ])
    ++ (with pkgs-unstable; [
      espressif-udev
      nrfconnect

      popsicle
    ]);
}
