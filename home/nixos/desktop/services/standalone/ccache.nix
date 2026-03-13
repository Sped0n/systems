{
  config,
  lib,
  pkgs,
  ...
}:
let
  standalone = config.services.standalone;

  ccacheDir = "/nix/var/cache/ccache";
in
{
  config = lib.mkIf standalone.enable {
    home.packages = [ pkgs.ccache ];

    nix.settings.extra-sandbox-paths = lib.mkAfter [ ccacheDir ];

    home.activation.ccacheDirNotice = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      red='\033[1;31m'
      yellow='\033[1;33m'
      reset='\033[0m'

      if [ ! -d "${ccacheDir}" ]; then
        $DRY_RUN_CMD printf '%b\n' "''${red}===== ''${reset}"
        $DRY_RUN_CMD printf '%b\n' "''${yellow}Directory '${ccacheDir}' does not exist''${reset}"
        $DRY_RUN_CMD printf '%s\n' "Please create it with:"
        $DRY_RUN_CMD printf '%s\n' "  sudo mkdir -m0770 '${ccacheDir}'"
        $DRY_RUN_CMD printf '%s\n' "  sudo chown root:nixbld '${ccacheDir}'"
        $DRY_RUN_CMD printf '%b\n' "''${red}===== ''${reset}"
        exit 1
      fi

      actual_owner_group="$(${pkgs.coreutils}/bin/stat -c '%U:%G' "${ccacheDir}")"
      actual_mode="$(${pkgs.coreutils}/bin/stat -c '%a' "${ccacheDir}")"

      if [ "$actual_owner_group" != "root:nixbld" ] || [ "$actual_mode" != "770" ]; then
        $DRY_RUN_CMD printf '%b\n' "''${red}===== ''${reset}"
        $DRY_RUN_CMD printf '%b\n' "''${yellow}Directory '${ccacheDir}' must be owned by root:nixbld with mode 0770''${reset}"
        $DRY_RUN_CMD printf '%s\n' "Current owner/group: $actual_owner_group"
        $DRY_RUN_CMD printf '%s\n' "Current mode: $actual_mode"
        $DRY_RUN_CMD printf '%s\n' "Please fix it with:"
        $DRY_RUN_CMD printf '%s\n' "  sudo chown root:nixbld '${ccacheDir}'"
        $DRY_RUN_CMD printf '%s\n' "  sudo chmod 0770 '${ccacheDir}'"
        $DRY_RUN_CMD printf '%b\n' "''${red}===== ''${reset}"
        exit 1
      fi
    '';
  };
}
