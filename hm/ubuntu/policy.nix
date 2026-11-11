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
              pkgs.procps
              config.nix.package
            ]
          }:/usr/sbin:/usr/bin:/sbin:/bin
          ${builtins.readFile ./scripts/policy.sh}
        ''}
      '';
}
