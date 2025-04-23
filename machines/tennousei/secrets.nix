{
  secrets,
  home,
  ...
}: {
  age = let
    readable = {
      mode = "0500";
    };
  in {
    identityPaths = [
      "${home}/.config/secrets/id_agenix"
    ];

    secrets = {
      "tennousei-cf-tunnel-json" =
        {
          file = "${secrets}/tennousei-cf-tunnel-json.age";
          owner = "root";
        }
        // readable;

      "restic-env" =
        {
          file = "${secrets}/restic-env.age";
          owner = "root";
        }
        // readable;

      "restic-password" =
        {
          file = "${secrets}/restic-password.age";
          owner = "root";
        }
        // readable;

      "rclone-webdav-htpasswd" =
        {
          file = "${secrets}/tennousei-rclone-webdav-htpasswd.age";
          owner = "root";
        }
        // readable;
    };
  };
}
