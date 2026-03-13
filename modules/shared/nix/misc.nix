{ pkgs, ... }:
{
  nix.channel.enable = false;
  environment.systemPackages = with pkgs; [
    nixos-rebuild-ng
  ];
}
