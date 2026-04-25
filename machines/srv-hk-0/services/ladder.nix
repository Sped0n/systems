{ vars, ... }:
{
  services.my-ladder.relay = {
    enable = true;
    exits = [
      vars.srv-sg-1.ipv4
      vars.srv-sg-0.ipv4
    ];
  };
}
