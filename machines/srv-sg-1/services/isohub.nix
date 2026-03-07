{ lib, vars, ... }:
{
  users.users.isohub = {
    isSystemUser = true;
    group = "users";
    openssh.authorizedKeys.keys = [ vars.srv-sg-1.isohubSftpPublicKey ];
  };

  users.users."${vars.username}".homeMode = "0710";

  services.openssh.extraConfig = lib.mkAfter ''
    Match User isohub
      ForceCommand internal-sftp -u 0002
      AllowTcpForwarding no
      X11Forwarding no
      PermitTunnel no
      PermitTTY no
      PasswordAuthentication no
  '';

  systemd.tmpfiles.rules = with vars; [
    "d ${home}/storage/isohub 2775 isohub users -"
    "z ${home}/storage/isohub 2775 isohub users -"
  ];
}
