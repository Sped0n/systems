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
      "smtp-password" =
        {
          file = "${secrets}/ages/smtp-password.age";
          owner = "root";
        }
        // readable;
    };
  };
}
