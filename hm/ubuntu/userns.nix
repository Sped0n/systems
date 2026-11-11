{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.activation.checkUbuntuUserns =
    lib.hm.dag.entryBetween [ "writeBoundary" ] [ "checkUbuntuHost" ]
      ''
        ${
          import ./setup-script.nix {
            inherit config lib pkgs;
            name = "ubuntu-userns-setup";
            description = "Disable AppArmor's unprivileged user namespace restriction until reboot. This relaxes a host-wide security restriction; no persistent sysctl configuration is written.";
            script = ./scripts/userns.sh;
          }
        } --check
      '';
}
