{secrets, ...}: {
  age.secrets = let
    readable = {
      mode = "0500";
    };
  in {
    "wg0-conf" =
      {
        file = "${secrets}/ages/tsuki-wg0-conf.age";
        owner = "root";
      }
      // readable;
  };
}
