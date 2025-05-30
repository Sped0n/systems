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
    systems = ["x86_64-linux" "aarch64-linux"];
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
      # We have to emulate aarch64 on x86 qemu, see https://github.com/golang/go/issues/69255
      boot.binfmt.emulatedSystems = ["aarch64-linux"];
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
