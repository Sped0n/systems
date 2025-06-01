{vars, ...}: {
  users.users.root = {
    openssh.authorizedKeys.keys = [vars.deploySSHKey];
  };
}
