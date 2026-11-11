{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.activation.checkUbuntuPolicy =
    lib.hm.dag.entryBetween [ "writeBoundary" ] [ "checkUbuntuHost" ]
      ''
        ${pkgs.writeShellScript "ubuntu-policy-check" ''
          export PATH=${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.gnugrep
              config.nix.package
            ]
          }:/usr/sbin:/usr/bin:/sbin:/bin
          ${config.lib.bash.initHomeManagerLib}
          ${builtins.readFile ./scripts/policy.sh}
        ''}
      '';
}
