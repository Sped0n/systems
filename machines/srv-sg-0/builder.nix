{ ... }:
{
  services.my-builder = {
    enable = true;
    deployees = [
      "srv-de-0"
      "srv-nl-0"
      "srv-sg-0"
      "srv-sg-2"
    ];
  };
}
