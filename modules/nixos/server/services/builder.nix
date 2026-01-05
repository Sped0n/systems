{
  lib,
  config,
  secrets,
  vars,
  ...
}:
let
  cfg = config.services.my-builder;
  hostname = config.networking.hostName;

  makeSecretAttr = hostName: {
    name = "${hostName}-ssh-key";
    value = {
      file = "${secrets}/ages/${hostName}-ssh-key.age";
      owner = "builder";
      mode = "0400";
    };
  };
  makeMatchBlockAttrs = hostName: [
    {
      name = hostName;
      value = {
        hostname = vars."${hostName}".ipv4;
        port = 12222;
        user = vars.username;
        identityFile = [
          config.age.secrets."${hostName}-ssh-key".path
        ];
      };
    }
  ];
in
{
  options.services.my-builder = {
    enable = lib.mkEnableOption "builder user, secrets, and SSH wiring for deployees";

    deployees = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Hostnames that need builder SSH configuration.
        The service expects `vars.<host>.ipv4` and `vars.username` to exist.
      '';
    };

    gcDates = lib.mkOption {
      type = lib.types.str;
      default = "*-01/2-01 00:00";
      description = "Cron-style schedule for Nix garbage collection.";
    };

    gcOptions = lib.mkOption {
      type = lib.types.str;
      default = "--delete-older-than 60d";
      description = "Additional options for Nix garbage collection.";
    };
  };

  config = lib.mkIf cfg.enable {
    users = {
      users.builder = {
        isNormalUser = true;
        group = "builder";
        openssh.authorizedKeys.keys = [
          vars."${hostname}".sshPublicKey
        ];
      };
      groups.builder = { };
    };

    nix = {
      gc = {
        dates = cfg.gcDates;
        options = cfg.gcOptions;
      };
      settings = {
        keep-outputs = true;
        keep-derivations = true;
        trusted-users = [ "builder" ];
      };
    };

    age.secrets = builtins.listToAttrs (map makeSecretAttr cfg.deployees);

    home-manager.users.builder = {
      home = {
        enableNixpkgsReleaseCheck = false;
        stateVersion = "24.11";
      };
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks = {
          "*" = {
            addKeysToAgent = "yes";
            identitiesOnly = true;
            extraOptions = {
              "TCPKeepAlive" = "yes";
            };
          };
        }
        // builtins.listToAttrs (lib.concatMap makeMatchBlockAttrs cfg.deployees);
      };
    };
  };
}
