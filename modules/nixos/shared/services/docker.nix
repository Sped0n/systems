{ config, lib, ... }:
let
  my-docker = config.services.my-docker;
in
{
  options.services.my-docker = {
    enable = lib.mkEnableOption "Whether to enable the custom Telegraf module.";

    docuumThreshold = lib.mkOption {
      type = lib.types.str;
      default = "10%";
      description = "The disk space threshold for Docuum to maintain.";
    };
  };

  config = lib.mkIf my-docker.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      daemon.settings = {
        log-driver = "journald";
        log-opts.tag = "docker#{{.Name}}({{.ID}})";
        max-concurrent-downloads = 2;
      };
    };

    services.docuum = {
      enable = true;
      threshold = my-docker.docuumThreshold;
    };
    systemd.services.docuum.environment.LOG_LEVEL = "info";
  };
}
