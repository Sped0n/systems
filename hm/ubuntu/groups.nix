{ lib, pkgs, ... }:
{
  home.activation.checkUbuntuGroups =
    lib.hm.dag.entryBetween [ "writeBoundary" ] [ "checkUbuntuHost" ]
      ''
        ${
          import ./setup-script.nix {
            inherit lib pkgs;
            name = "ubuntu-groups-setup";
            description = "Ensure the workstation user belongs to dialout and plugdev, creating these groups if necessary.";
            script = ./scripts/groups.sh;
          }
        } --check
      '';
}
