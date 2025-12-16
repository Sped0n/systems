{
  config,
  lib,
  pkgs-unstable,
  secrets,
  ...
}:
let
  cfg = config.services.my-runner;
  hostname = config.networking.hostName;
  token = config.age.secrets."forgejo-runner-token".path;
in
{
  options.services.my-runner = {
    enable = lib.mkEnableOption "Enable Forgejo runner";

    labels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "docker:docker://catthehacker/ubuntu:act-latest"
      ];
      description = "Labels advertised by this runner.";
    };

    capacity = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Maximum concurrent jobs.";
    };

    dockerOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--memory=4g"
        "--memory-swap=8g"
        "--cpus=3"
      ];
      description = "Extra docker run options.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets."forgejo-runner-token" = {
      file = "${secrets}/ages/forgejo-runner-token.age";
      owner = "root";
      mode = "0400";
    };

    services.gitea-actions-runner = {
      package = pkgs-unstable.forgejo-runner;
      instances.alfa = {
        enable = true;
        name = "${hostname}-alfa";
        tokenFile = token;
        url = "https://git.sped0n.com/";
        labels = cfg.labels;
        settings = {
          runner = {
            capacity = cfg.capacity;
            fetch_interval = "30s";
          };
          container = {
            docker_host = "automount";
            options = lib.concatStringsSep " " cfg.dockerOptions;
            force_pull = true;
          };
        };
      };
    };

    networking.firewall.trustedInterfaces = [ "br-+" ];
  };
}
