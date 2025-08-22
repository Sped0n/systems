{ pkgs, ... }:
{
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
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
}
