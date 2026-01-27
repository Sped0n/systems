{
  config,
  functions,
  lib,
  pkgs,
  vars,
  ...
}:
let
  hostname = config.networking.hostName;
  my-docker = config.services.my-docker;
  smtpPasswordPath = config.age.secrets."smtp-password".path;

  yaml = pkgs.formats.yaml { };
in
{
  config = lib.mkIf my-docker.enable {
    users = {
      users.diun = {
        isSystemUser = true;
        group = "diun";
        extraGroups = [
          "docker"
          "smtp-auth-users"
        ];
      };
      groups.diun = { };
    };

    systemd.services.diun = {
      description = "Diun (Docker Image Update Notifier)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        User = "diun";
        Group = "diun";

        StateDirectory = "diun";
        StateDirectoryMode = "0750";
        WorkingDirectory = "/var/lib/diun";

        ExecStart = "${
          pkgs.callPackage (functions.fromRoot "/packages/diun.nix") { }
        }/bin/diun serve --config ${
          (yaml.generate "diun.yml" {
            db.path = "/var/lib/diun/diun.db";
            watch.schedule = "0 8 * * *";
            providers.docker.watchByDefault = true;
            notif.mail = {
              host = "smtp.resend.com";
              port = 465;
              ssl = true;
              username = "resend";
              # https://crazymax.dev/diun/faq/#secrets-loaded-from-files-and-trailing-newlines
              # do trim newline when editing the secret file
              # like `:set nofixeol` + `:set noeol` + `:wq` in neovim
              passwordFile = smtpPasswordPath;
              from = vars.infraEmail;
              to = [ vars.personalEmail ];
              templateTitle = "[${hostname}] {{ .Entry.Image }} released";
              templateBody = ''
                Docker tag {{ .Entry.Image }} which you subscribed to through {{ .Entry.Provider }} provider has been released.
              '';
            };
          })
        } --log-level warn";
        Restart = "always";
        RestartSec = "2s";
      };
    };
  };
}
