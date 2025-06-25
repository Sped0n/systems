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
    "aws-cli-credentials" =
      {
        path = "${home}/.aws/credentials";
        file = "${secrets}/ages/suisei-aws-cli-credentials.age";
      }
      // readable;
  };
}
