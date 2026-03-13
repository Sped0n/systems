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
    hosts."github.com" = {
      git_protocol = "https";
      users.Sped0n = { };
      user = "Sped0n";
    };
    settings = {
      git_protocol = "https";
      spinner = "enabled";
    };
  };
}
