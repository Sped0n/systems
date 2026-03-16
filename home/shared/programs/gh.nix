{
  lib,
  pkgs-unstable,
  ...
}:
{
  programs.gh = {
    enable = lib.mkDefault false;
    package = pkgs-unstable.gh;
    gitCredentialHelper = {
      enable = true;
      hosts = [
        "https://github.com"
        "https://gist.github.com"
      ];
    };
    settings = {
      git_protocol = "https";
      spinner = "enabled";
    };
  };
}
