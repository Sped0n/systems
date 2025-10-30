{ vars, ... }:
{
  services.my-builder = {
    enable = true;
    deployees = [ "calibarn" ];
    authorizedKeys = [
      vars.calibarn.builderSshPublicKey
    ];
  };
}
