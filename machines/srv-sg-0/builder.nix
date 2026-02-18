{ ... }:
{
  services.my-builder = {
    enable = true;
    deployees = [
      "srv-de-0"
      "srv-hk-0"
      "srv-jp-0"
      "srv-nl-0"
      "srv-sg-0"
      "srv-us-0"
    ];
  };
}
