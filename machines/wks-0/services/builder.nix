{ ... }:
{
  services.my-linux-builder = {
    enable = true;
    cores = 6;
    memory = "8192M";
    image = "ghcr.io/sped0n/darwin-builder:latest";
  };
}
