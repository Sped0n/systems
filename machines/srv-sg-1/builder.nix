{ ... }:
{
  services.my-builder = {
    enable = true;
    deployees = [ "srv-sg-1" ];
  };
}
