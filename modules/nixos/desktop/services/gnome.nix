{ lib, pkgs, ... }:
{
  services = {
    xserver.enable = true;
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };

  environment.gnome.excludePackages = with pkgs; [
    atomix # puzzle game
    hitori # sudoku game
    iagno # go game
    tali # poker game

    cheese # webcam tool
    epiphany # web browser
    geary # email reader
    gedit # text editor
    simple-scan # document scanner

    gnome-characters
    gnome-music
    gnome-photos
    gnome-terminal
    gnome-console
    gnome-tour
    gnome-contacts
    gnome-text-editor
    gnome-maps
  ];

  # conflict between programs.ssh.startAgent and services.gnome.gcr-ssh-agent.enable
  programs.ssh.startAgent = lib.mkForce false;
}
