{ vars, ... }:
{
  services.my-builder = {
    enable = true;
    deployees = [
      "banshee"
      "exia"
      "phenex"
    ];
    authorizedKeys = [
      vars.calibarn.builderSshPublicKey
    ];
  };
}
