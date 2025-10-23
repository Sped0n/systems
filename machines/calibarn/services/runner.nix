{
  config,
  pkgs-unstable,
  secrets,
  ...
}:
{
  age.secrets."forgejo-runner-token" = {
    file = "${secrets}/ages/forgejo-runner-token.age";
    owner = "root";
    mode = "0400";
  };

  services.gitea-actions-runner = {
    package = pkgs-unstable.forgejo-runner;
    instances.alfa = {
      enable = true;
      name = "calibarn-alfa";
      tokenFile = config.age.secrets."forgejo-runner-token".path;
      url = "https://git.sped0n.com/";
      labels = [
        "docker:docker://node:lts-trixie"
        "docker-aarch64:docker://node:lts-trixie"
      ];
      settings = {
        runner = {
          capacity = 2;
          fetch_interval = "30s";
        };
        container = {
          docker_host = "automount";
          options = builtins.concatStringsSep " " [
            "--memory=6g"
            "--memory-swap=10g"
            "--cpus=2"
          ];
          force_pull = true;
        };
      };
    };
  };

  networking.firewall.trustedInterfaces = [ "br-+" ];
}
