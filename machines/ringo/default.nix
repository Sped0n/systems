{
  pkgs,
  username,
  ...
}: {
  imports = [
    ../../modules/darwin
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "${username}";
  };

  nix.linux-builder = {
    enable = true;
    package = pkgs.darwin.linux-builder-x86_64;
    ephemeral = true;
    maxJobs = 6;
    config = {
      virtualisation = {
        cores = 6;
        darwin-builder = {
          diskSize = 30 * 1024;
          memorySize = 6 * 1024;
        };
      };
    };
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
