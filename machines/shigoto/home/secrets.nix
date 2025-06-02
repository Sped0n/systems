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
      "github-ssh-key" =
        {
          path = "${home}/.ssh/id_github";
          file = "${secrets}/ages/github-ssh-key.age";
        }
        // readable;

      # NOTE: disable after imported
      # "github-signing-key" =
      #   {
      #     path = "${home}/.config/secrets/pgp_github.key";
      #     file = "${secrets}/ages/github-signing-key.age";
      #   }
      #   // readable;

      "server-ssh-key" =
        {
          path = "${home}/.ssh/id_server";
          file = "${secrets}/ages/server-ssh-key.age";
        }
        // readable;
    };
  };
}
