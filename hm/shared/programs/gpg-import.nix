{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  githubCfg = config.programs.gpg-import-github-key;
  workCfg = config.programs.gpg-import-work-key;

  mkSigningKeySecret = fileName: {
    file = "${secrets}/ages/${fileName}";
    mode = "0400";
  };

  mkGpgImportScript =
    {
      name,
      keyPath,
      keyLabel,
    }:
    pkgs.writeShellScriptBin name ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      if [ "$(id -u)" -eq 0 ]; then
        ${pkgs.coreutils}/bin/echo "Error: Do not run this script with sudo." >&2
        exit 1
      fi

      KEY_FILE="${keyPath}"
      ${pkgs.coreutils}/bin/echo "Importing ${keyLabel} signing key from ''${KEY_FILE}..."
      ${pkgs.coreutils}/bin/cat "''${KEY_FILE}" | ${pkgs.gnupg}/bin/gpg --import
      ${pkgs.coreutils}/bin/echo "Key import successful."
    '';
in
{
  options.programs = {
    gpg-import-github-key.enable = lib.mkEnableOption "Import GitHub signing key from agenix secret";
    gpg-import-work-key.enable = lib.mkEnableOption "Import work signing key from agenix secret";
  };

  config = {
    age.secrets =
      lib.optionalAttrs githubCfg.enable {
        "github-signing-key" = mkSigningKeySecret "github-signing-key.age";
      }
      // lib.optionalAttrs workCfg.enable {
        "espressif-signing-key" = mkSigningKeySecret "espressif-signing-key.age";
      };

    home.packages =
      lib.optionals githubCfg.enable [
        (mkGpgImportScript {
          name = "gpg-import-github-key";
          keyPath = config.age.secrets."github-signing-key".path;
          keyLabel = "GitHub";
        })
      ]
      ++ lib.optionals workCfg.enable [
        (mkGpgImportScript {
          name = "gpg-import-work-key";
          keyPath = config.age.secrets."espressif-signing-key".path;
          keyLabel = "work";
        })
      ];
  };
}
