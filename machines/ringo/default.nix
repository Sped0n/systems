{
  # pkgs,
  username,
  ...
}: {
  imports = [
    ../../modules/darwin

    ./builder.nix
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "${username}";
  };

  home-manager = {
    users.${username} = {...}: {
      imports = [./home];
      home = {
        enableNixpkgsReleaseCheck = false;
        stateVersion = "24.11";
      };
    };
  };

  homebrew.masApps = {
    "WeChat" = 836500024;
    "WhatsApp Messenger" = 310633997;
    "Endel" = 1346247457;
    "VidHub" = 1659622164;
    "Windows App" = 1295203466;
    "Microsoft Word" = 462054704;
    "Microsoft Excel" = 462058435;
    "Microsoft PowerPoint" = 462062816;
    "Microsoft Outlook" = 985367838;
    "Microsoft OneDrive" = 823766827;
    "PDFgear" = 6469021132;
  };
}
