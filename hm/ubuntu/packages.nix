{
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages =
    (with pkgs; [
      nixos-rebuild-ng

      llm-agents.cursor-agent
    ])
    ++ (with pkgs-unstable; [
      espressif-udev
      nrfconnect

      popsicle
    ]);

  home.activation.checkUbuntuPackages =
    lib.hm.dag.entryBetween [ "writeBoundary" ] [ "checkUbuntuHost" ]
      ''
        ${
          import ./setup-script.nix {
            inherit lib pkgs;
            name = "ubuntu-packages-setup";
            description = "Install the Ubuntu packages ssh-askpass-gnome and zram-tools without upgrading the distribution.";
            script = ./scripts/packages.sh;
          }
        } --check
      '';
}
