{
  pkgs,
  secrets,
  config,
  ...
}: {
  age.secrets."github-signing-key" = {
    file = "${secrets}/ages/github-signing-key.age";
    owner = "root";
    mode = "0400";
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "gpg-import-github-key" ''
      #!${pkgs.bash}/bin/bash
      set -e

      if [ "$(id -u)" -eq 0 ]; then
        ${pkgs.coreutils}/bin/echo "Error: Do not run this script with sudo." >&2
        exit 1
      fi

      KEY_FILE="${config.age.secrets."github-signing-key".path}"
      ${pkgs.coreutils}/bin/echo "Importing GitHub signing key from ''${KEY_FILE}..."
      sudo ${pkgs.coreutils}/bin/cat "''${KEY_FILE}" | ${pkgs.gnupg}/bin/gpg --import
      ${pkgs.coreutils}/bin/echo "Key import successful."
    '')
  ];
}
