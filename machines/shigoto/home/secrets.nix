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
          file = "${secrets}/github-ssh-key.age";
        }
        // readable;

      # NOTE: disable after imported
      # "github-signing-key" =
      #   {
      #     path = "${home}/.config/secrets/pgp_github.key";
      #     file = "${secrets}/github-signing-key.age";
      #   }
      #   // readable;

      "espressif-ssh-key" =
        {
          path = "${home}/.ssh/id_espressif";
          file = "${secrets}/espressif-ssh-key.age";
        }
        // readable;

      "tennousei-ssh-key" =
        {
          path = "${home}/.ssh/id_tennousei";
          file = "${secrets}/tennousei-ssh-key.age";
        }
        // readable;
    };
  };
}
