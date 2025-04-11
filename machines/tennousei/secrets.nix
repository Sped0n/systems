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
          path = "${home}/.config/secrets/cf-tunnel.json";
          file = "${secrets}/tennousei-cf-tunnel-json.age";
          owner = "root";
        }
        // readable;
    };
  };
}
