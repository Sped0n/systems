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
    "Flow" = 1423210932;
    "FastZip" = 1565629813;
  };
}
