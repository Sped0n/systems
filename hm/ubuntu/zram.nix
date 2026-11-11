{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.activation.checkUbuntuZram =
    lib.hm.dag.entryBetween [ "writeBoundary" ] [ "checkUbuntuHost" ]
      ''
        ${
          import ./setup-script.nix {
            inherit config lib pkgs;
            name = "ubuntu-zram-setup";
            description = "Configure zram to use 50% of RAM, lz4 compression, and swap priority 100, then restart zramswap.service.";
            script = ./scripts/zram.sh;
          }
        } --check
      '';
}
