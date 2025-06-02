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
      "wg0-conf" =
        {
          file = "${secrets}/ages/tsuki-wg0-conf.age";
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
    };
  };
}
