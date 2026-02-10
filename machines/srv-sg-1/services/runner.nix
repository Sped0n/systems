{ ... }:
{
  services.my-runner = {
    enable = true;
    labels = [
      "docker:docker://catthehacker/ubuntu:act-latest"
      "docker-aarch64:docker://catthehacker/ubuntu:act-latest"
    ];
    capacity = 2;
    dockerOptions = [
      "--memory=6g"
      "--memory-swap=10g"
      "--cpus=2"
    ];
    cacheMaxSizeInGib = 20;
  };
}
