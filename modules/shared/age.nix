{
  config,
  secrets,
  vars,
  ...
}:
{
  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets."ssh_user_ed25519_key" = {
      file = "${secrets}/ages/${config.networking.hostName}-user.age";
      owner = vars.username;
      mode = "0400";
      path = "/etc/ssh/ssh_user_ed25519_key";
    };
  };
}
