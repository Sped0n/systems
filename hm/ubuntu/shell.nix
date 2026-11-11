{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.activation.checkUbuntuShell = lib.hm.dag.entryAfter [ "linkGeneration" "checkUbuntuHost" ] ''
    ${
      import ./setup-script.nix {
        inherit config lib pkgs;
        name = "ubuntu-shell-setup";
        description = "Register the Home Manager Zsh profile path in /etc/shells and set it as the workstation user's login shell.";
        variables = {
          shell_path = "${config.home.profileDirectory}/bin/zsh";
          shell_user = config.home.username;
        };
        script = ./scripts/shell.sh;
      }
    } --check
  '';
}
