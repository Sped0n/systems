{
  vars,
  username,
  ...
}: {
  users.users."${username}" = {
    openssh.authorizedKeys.keys = [vars.tennousei.primarySSHKey];
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [vars.tennousei.primarySSHKey];
  };
}
