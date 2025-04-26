{
  pkgs,
  config,
  vars,
  ...
}: {
  programs.msmtp = {
    enable = true;
    defaults = {
      auth = true;
      tls = true;
      tls_starttls = false;
    };
    accounts.default = {
      host = vars.smtpHost;
      port = 465;
      user = vars.smtpUsername;
      passwordeval = "${pkgs.coreutils}/bin/cat ${config.age.secrets."smtp-password".path}";
      from = vars.infraEmail;
    };
  };
}
