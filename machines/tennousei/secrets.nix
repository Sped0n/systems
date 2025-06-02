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
          file = "${secrets}/ages/tennousei-cf-tunnel-json.age";
          owner = "root";
        }
        // readable;

      "restic-env" =
        {
          file = "${secrets}/ages/restic-env.age";
          owner = "root";
        }
        // readable;

      "restic-password" =
        {
          file = "${secrets}/ages/restic-password.age";
          owner = "root";
        }
        // readable;

      "rclone-webdav-htpasswd" =
        {
          file = "${secrets}/ages/tennousei-rclone-webdav-htpasswd.age";
          owner = "root";
        }
        // readable;
    };
  };
}
