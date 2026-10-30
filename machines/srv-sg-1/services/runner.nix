{ ... }:
{
  services.my-runner = {
    enable = true;
    labels = [
      "docker:docker://ghcr.io/catthehacker/ubuntu:runner-latest"
      "docker-aarch64:docker://ghcr.io/catthehacker/ubuntu:runner-latest"
    ];
    capacity = 2;
    dockerOptions = [
      "--memory=6g"
      "--memory-swap=9g"
      "--cpus=2"
    ];
    cacheMaxSizeInGib = 20;
  };
}
