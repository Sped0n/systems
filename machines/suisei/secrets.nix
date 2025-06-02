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

      "server-ssh-key" =
        {
          path = "/root/.ssh/id_server";
          file = "${secrets}/ages/server-ssh-key.age";
          owner = "root";
        }
        // readable;
    };
  };
}
