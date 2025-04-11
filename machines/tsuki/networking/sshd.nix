{
  vars,
  username,
  ...
}: {
  users.users."${username}" = {
    openssh.authorizedKeys.keys = [vars.tsuki.primarySSHKey];
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [vars.tsuki.primarySSHKey];
  };
}
