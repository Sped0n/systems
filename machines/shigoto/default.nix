{
  home,
  username,
  ...
}: {
  imports = [
    ./home
  ];

  home.username = username;
  home.homeDirectory = home;
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;
}
