{ ... }:
{
  services.my-runner = {
    enable = true;
    labels = [
      "docker:docker://catthehacker/ubuntu:act-latest"
      "docker-x86_64:docker://catthehacker/ubuntu:act-latest"
    ];
    capacity = 1;
    dockerOptions = [
      "--memory=4g"
      "--memory-swap=8g"
      "--cpus=3"
    ];
    cacheMaxSizeInGib = 5;
  };
}
