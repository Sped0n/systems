{ ... }:
{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    daemon.settings = {
      log-driver = "journald";
      log-opts.tag = "docker#{{.Name}}({{.ID}})";
      max-concurrent-downloads = 2;
    };
  };
}
