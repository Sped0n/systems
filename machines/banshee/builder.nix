{ vars, ... }:
{
  services.my-builder = {
    enable = true;
    deployees = [
      "banshee"
      "exia"
      "unicorn"
    ];
    authorizedKeys = [
      vars.calibarn.builderSshPublicKey
    ];
  };
}
