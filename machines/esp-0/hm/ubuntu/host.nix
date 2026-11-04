{ lib, ... }:
{
  home.activation.checkUbuntuHost = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    (
      # shellcheck source=/dev/null
      source /etc/os-release
      if [[ "''${ID:-}" != ubuntu ]]; then
        errorEcho "This configuration supports Ubuntu only; detected ''${ID:-unknown}."
        exit 1
      fi
      if [[ "$EUID" -eq 0 ]]; then
        errorEcho "Activate this configuration from the workstation user account, not a root shell."
        exit 1
      fi
    )
  '';
}
