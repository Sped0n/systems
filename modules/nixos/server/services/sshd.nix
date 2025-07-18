{
  username,
  vars,
  ...
}: {
  users.users.root = {
    openssh.authorizedKeys.keys = [vars.serverPublicKey];
  };

  users.users."${username}" = {
    openssh.authorizedKeys.keys = [vars.serverPublicKey];
  };
}
