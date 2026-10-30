{ ... }:
{
  services.my-runner = {
    enable = true;
    labels = [
      "docker:docker://ghcr.io/catthehacker/ubuntu:runner-latest"
      "docker-x86_64:docker://ghcr.io/catthehacker/ubuntu:runner-latest"
    ];
    capacity = 1;
    dockerOptions = [
      "--memory=4g"
      "--memory-swap=6g"
      "--cpus=3"
    ];
    cacheMaxSizeInGib = 5;
  };
}
