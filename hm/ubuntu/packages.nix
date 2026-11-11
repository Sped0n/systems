{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  home.packages =
    (with pkgs; [
      nixos-rebuild-ng

      nrfconnect

      llm-agents.cursor-agent
    ])
    ++ (with pkgs-unstable; [
      espressif-udev

      popsicle
    ]);

  home.activation.checkUbuntuPackages =
    lib.hm.dag.entryBetween [ "writeBoundary" ] [ "checkUbuntuHost" ]
      ''
        ${
          import ./setup-script.nix {
            inherit config lib pkgs;
            name = "ubuntu-packages-setup";
            description = "Install the Ubuntu packages ssh-askpass-gnome and zram-tools without upgrading the distribution.";
            script = ./scripts/packages.sh;
          }
        } --check
      '';
}
