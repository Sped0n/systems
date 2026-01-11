{
  config,
  functions,
  pkgs,
  vars,
  ...
}:

let
  yaml = pkgs.formats.yaml { };
  diunConfigFile = yaml.generate "diun.yml" {
    watch = {
      workers = 10;
      schedule = "0 8 * * *";
      runOnStartup = true;
    };

    providers.docker.watchByDefault = true;

    notif.mail = {
      host = "smtp.resend.com";
      port = 465;
      ssl = true;
      username = "resend";
      from = vars.infraEmail;
      to = [ vars.personalEmail ];
      templateTitle = "{{ .Entry.Image }} released | ${config.networking.hostName}";
      templateBody = ''
        Docker tag {{ .Entry.Image }} which you subscribed to through {{ .Entry.Provider }} provider has been released.
      '';
    };
  };
in
{
  users.users.diun = {
    isSystemUser = true;
    group = "diun";
    extraGroups = [
      "docker"
      "smtp-auth-users"
    ];
  };
  users.groups.diun = { };

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

      Environment = [
        "DIUN_DB_PATH=/var/lib/diun/diun.db"
        "DIUN_NOTIF_MAIL_PASSWORDFILE=${config.age.secrets."smtp-password".path}"
      ];

      ExecStart = "${
        pkgs.callPackage (functions.fromRoot "/packages/diun.nix") { }
      }/bin/diun serve --config ${diunConfigFile} --log-level warn";
      Restart = "always";
      RestartSec = "2s";
    };
  };
}
