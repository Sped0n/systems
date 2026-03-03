{
  config,
  pkgs,
  secrets,
  ...
}:
{
  age.secrets = {
    "github-signing-key" = {
      file = "${secrets}/ages/github-signing-key.age";
      owner = "root";
      mode = "0400";
    };
    "espressif-signing-key" = {
      file = "${secrets}/ages/espressif-signing-key.age";
      owner = "root";
      mode = "0400";
    };
  };

  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "gpg-import-github-key";
      runtimeInputs = with pkgs; [
        coreutils
        gnupg
        sudo
      ];
      text = ''
        set -e

        if [ "$(id -u)" -eq 0 ]; then
          echo "Error: Do not run this script with sudo." >&2
          exit 1
        fi

        KEY_FILE="${config.age.secrets."github-signing-key".path}"
        echo "Importing GitHub signing key from ''${KEY_FILE}..."
        gpg --import <(sudo cat "''${KEY_FILE}")
        echo "Key import successful."
      '';
    })
    (pkgs.writeShellApplication {
      name = "gpg-import-work-key";
      runtimeInputs = with pkgs; [
        coreutils
        gnupg
        sudo
      ];
      text = ''
        set -e

        if [ "$(id -u)" -eq 0 ]; then
          echo "Error: Do not run this script with sudo." >&2
          exit 1
        fi

        KEY_FILE="${config.age.secrets."espressif-signing-key".path}"
        echo "Importing work signing key from ''${KEY_FILE}..."
        gpg --import <(sudo cat "''${KEY_FILE}")
        echo "Key import successful."
      '';
    })
  ];
}
