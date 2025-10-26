{
  vars,
  ...
}:
{
  imports = [ ./deployment.nix ];

  users = {
    users.builder = {
      isNormalUser = true;
      group = "builder";
      openssh.authorizedKeys.keys = [
        vars.calibarn.builderSshPublicKey
      ];
    };
    groups.builder = { };
  };

  nix = {
    gc = {
      dates = "*-01/2-01 00:00";
      options = "--delete-older-than 60d";
    };
    settings = {
      keep-outputs = true;
      keep-derivations = true;
      trusted-users = [ "builder" ];
    };
  };
}
