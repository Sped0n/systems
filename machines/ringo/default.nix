{
  lib,
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
    systems = ["x86_64-linux" "aarch64-linux"];
    ephemeral = true;
    maxJobs = 6;
    config = {
      virtualisation = {
        cores = 6;
        darwin-builder = {
          diskSize = 30 * 1024;
          # we have two emulated runners, so max memory usage would be 8GiB
          memorySize = 4 * 1024;
        };
      };

      # please comment below config for the very first run
      boot.binfmt.emulatedSystems = ["x86_64-linux"];
      systemd.coredump.enable = false;
      swapDevices = lib.mkOverride 9 [
        {
          device = "/swapfile";
          size = 2 * 1024;
        }
      ];
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
