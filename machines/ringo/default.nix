{username, ...}: {
  imports = [
    ../../modules/darwin
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "${username}";
  };

  # nix.linux-builder = {
  #   enable = true;
  #   systems = ["x86_64-linux" "aarch64-linux"];
  #   ephemeral = true;
  #   maxJobs = 1;
  #   config = {
  #     boot.binfmt.emulatedSystems = ["x86_64-linux"];
  #     virtualisation = {
  #       darwin-builder = {
  #         diskSize = 30 * 1024;
  #         memorySize = 3 * 1024; # qemu seems to have a 2x memeory leak
  #       };
  #       cores = 4;
  #     };
  #   };
  # };

  nix-rosetta-builder = {
    enable = true;
    cores = 6;
    memory = "6GiB";
    diskSize = "40GiB";
    onDemand = true;
    onDemandLingerMinutes = 60;
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
    "Photomator" = 1444636541;
    "VidHub" = 1659622164;
  };
}
