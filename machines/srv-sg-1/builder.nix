{ vars, ... }:
{
  services.my-builder = {
    enable = true;
    deployees = [ "srv-sg-1" ];
    authorizedKeys = [
      vars.srv-sg-1.builderSshPublicKey
    ];
  };
}
