{ libutils, vars, ... }:
{
  imports = [
    (libutils.fromRoot "/modules/darwin")

    ./agenix.nix
    ./casks.nix
  ];

  networking.hostName = "dendrobium";

  determinate-nix.customSettings = {
    extra-experimental-features = "external-builders";
    external-builders = ''
      [{"systems":["aarch64-linux","x86_64-linux"],"program":"/usr/local/bin/determinate-nixd","args":["builder"]}]
    '';
  };

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "${vars.username}";
  };

  home-manager.users.${vars.username} =
    { ... }:
    {
      imports = [ ./home ];
      home = {
        enableNixpkgsReleaseCheck = false;
        stateVersion = "24.11";
      };
    };

  homebrew.masApps = {
    "Dropover" = 1355679052;
    "Endel" = 1346247457;
    "VidHub" = 1659622164;
    "PDFgear" = 6469021132;
  };
}
