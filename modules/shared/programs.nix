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
    owner = "root";
    mode = "0400";
  };
  mkGpgImportScript =
    {
      name,
      keyPath,
      keyLabel,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs =
        (with pkgs; [
          coreutils
          gnupg
        ])
        ++ lib.optional pkgs.stdenv.isLinux pkgs.sudo;
      text = ''
        set -e

        if [ "$(id -u)" -eq 0 ]; then
          echo "Error: Do not run this script with sudo." >&2
          exit 1
        fi

        KEY_FILE="${keyPath}"
        echo "Importing ${keyLabel} signing key from ''${KEY_FILE}..."
        gpg --import <(sudo cat "''${KEY_FILE}")
        echo "Key import successful."
      '';
    };
in
{
  options.programs = {
    gpg-import-github-key.enable = lib.mkEnableOption "Import GitHub signing key from agenix secret";
    gpg-import-work-key.enable = lib.mkEnableOption "Import work signing key from agenix secret";
  };

  config = {
    age.secrets = lib.mkMerge [
      (lib.mkIf githubCfg.enable {
        "github-signing-key" = mkSigningKeySecret "github-signing-key.age";
      })
      (lib.mkIf workCfg.enable {
        "espressif-signing-key" = mkSigningKeySecret "espressif-signing-key.age";
      })
    ];

    environment.systemPackages = lib.mkMerge [
      (lib.mkIf githubCfg.enable [
        (mkGpgImportScript {
          name = "gpg-import-github-key";
          keyPath = config.age.secrets."github-signing-key".path;
          keyLabel = "GitHub";
        })
      ])
      (lib.mkIf workCfg.enable [
        (mkGpgImportScript {
          name = "gpg-import-work-key";
          keyPath = config.age.secrets."espressif-signing-key".path;
          keyLabel = "work";
        })
      ])
    ];
  };
}
