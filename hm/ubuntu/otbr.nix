{ lib, pkgs, ... }:
{
  home.activation.checkUbuntuOtbr =
    lib.hm.dag.entryBetween [ "writeBoundary" ] [ "checkUbuntuHost" ]
      ''
        ${
          import ./setup-script.nix {
            inherit lib pkgs;
            name = "ubuntu-otbr-setup";
            description = "Configure IPv6 router advertisements for OTBR on the selected uplink. This overwrites the workstation IPv6 sysctl and NetworkManager dispatcher files.";
            script = ./scripts/otbr.sh;
          }
        } --check
      '';
}
