{ lib, pkgs, ... }:
{
  system.installer.channel.enable = false;

  documentation = {
    enable = lib.mkForce false;
    nixos.enable = lib.mkForce false;
  };

  services = {
    speechd.enable = false;
    pipewire.enable = lib.mkForce false;
  };

  fonts = {
    enableDefaultPackages = false;
    fontconfig.enable = false;
    packages = lib.mkForce (
      with pkgs;
      [
        dejavu_fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
      ]
    );
  };

  environment.gnome.excludePackages = with pkgs; [
    decibels # audio player
    epiphany # web browser
    geary # mail client
    gedit # text editor
    loupe # image viewer
    orca # screen reader
    papers # document viewer
    showtime # video player
    simple-scan # document scanner
    snapshot # camera viewer
    yelp # help viewer

    gnome-calendar
    gnome-characters
    gnome-clocks
    gnome-connections
    gnome-contacts
    gnome-font-viewer
    gnome-logs
    gnome-maps
    gnome-music
    gnome-tour
    gnome-user-docs
    gnome-weather
  ];
}
