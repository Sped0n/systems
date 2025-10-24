{ username, ... }:
{
  imports = [
    ../../modules/darwin

    ./agenix.nix
    ./casks.nix
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "${username}";
  };

  home-manager = {
    users.${username} =
      { ... }:
      {
        imports = [ ./home ];
        home = {
          enableNixpkgsReleaseCheck = false;
          stateVersion = "24.11";
        };
      };
  };

  homebrew.masApps = {
    "Dropover" = 1355679052;
    "Endel" = 1346247457;
    "VidHub" = 1659622164;
    "PDFgear" = 6469021132;
  };
}
