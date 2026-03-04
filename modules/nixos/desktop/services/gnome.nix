{ lib, pkgs, ... }:
{
  services = {
    xserver.enable = true;
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };

  environment.gnome.excludePackages = with pkgs; [
    epiphany # web browser
    geary # mail client
    gedit # text editor
    orca # screen reader
    simple-scan # document scanner
    snapshot # camera viewer
    yelp # help viewer

    gnome-characters
    gnome-connections
    gnome-console
    gnome-contacts
    gnome-logs
    gnome-maps
    gnome-music
    gnome-text-editor
    gnome-tour
    gnome-user-docs
    gnome-weather
  ];

  # conflict between programs.ssh.startAgent and services.gnome.gcr-ssh-agent.enable
  programs.ssh.startAgent = lib.mkForce false;
}
