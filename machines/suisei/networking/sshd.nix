{
  vars,
  username,
  ...
}: {
  users.users."${username}" = {
    openssh.authorizedKeys.keys = [vars.suisei.primarySSHKey];
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [vars.suisei.primarySSHKey];
  };
}
