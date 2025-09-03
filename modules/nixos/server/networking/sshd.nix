{
  username,
  vars,
  ...
}:
{
  services = {
    openssh = {
      enable = true;
      settings = {
        X11Forwarding = true;
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
      openFirewall = true;
      ports = [ 12222 ];
    };
    fail2ban.jails.sshd.settings.findtime = "6h";
  };

  # Add terminfo database of all known terminals to the system profile.
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.11/nixos/modules/config/terminfo.nix
  environment.enableAllTerminfo = true;

  users.users = {
    root.openssh.authorizedKeys.keys = [ vars.serverPublicKey ];
    "${username}".openssh.authorizedKeys.keys = [ vars.serverPublicKey ];
  };
}
