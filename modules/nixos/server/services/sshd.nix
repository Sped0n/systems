{ config, vars, ... }:
{
  services = {
    openssh = {
      enable = true;
      settings = {
        X11Forwarding = false;
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        UseDns = false;
      };
      extraConfig = ''
        MaxAuthTries 3
        ClientAliveCountMax 3
        ClientAliveInterval 120
      '';
      openFirewall = true;
      ports = [ 12222 ];
    };
    fail2ban.jails.sshd.settings.findtime = "6h";
  };

  # Add terminfo database of all known terminals to the system profile.
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.11/nixos/modules/config/terminfo.nix
  environment.enableAllTerminfo = true;

  users.users."${vars.username}".openssh.authorizedKeys.keys = [
    vars."${config.networking.hostName}".sshPublicKey
  ];
}
