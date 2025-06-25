{
  secrets,
  home,
  ...
}: {
  age.secrets = let
    readable = {
      mode = "0500";
    };
  in {
    "server-ssh-key" =
      {
        path = "${home}/.ssh/id_server";
        file = "${secrets}/ages/server-ssh-key.age";
      }
      // readable;
  };
}
