{secrets, ...}: {
  age.secrets = let
    readable = {
      mode = "0500";
    };
  in {
    "server-ssh-key" =
      {
        path = "/root/.ssh/id_server";
        file = "${secrets}/ages/server-ssh-key.age";
        owner = "root";
      }
      // readable;
  };
}
