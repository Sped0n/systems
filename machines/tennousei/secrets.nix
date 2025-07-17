{secrets, ...}: {
  age.secrets = let
    readable = {
      mode = "0500";
    };
  in {
    "tennousei-cf-tunnel-json" =
      {
        file = "${secrets}/ages/tennousei-cf-tunnel-json.age";
        owner = "root";
      }
      // readable;

    "rclone-webdav-htpasswd" =
      {
        file = "${secrets}/ages/tennousei-rclone-webdav-htpasswd.age";
      }
      // readable;
  };
}
