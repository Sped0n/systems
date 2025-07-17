{
  home,
  secrets,
  ...
}: {
  age.secrets = {
    "aws-cli-credentials" = {
      path = "${home}/.aws/credentials";
      file = "${secrets}/ages/suisei-aws-cli-credentials.age";
      mode = "0400";
    };
  };

  programs.awscli = {
    enable = true;
    settings = {
      "default" = {
        region = "garage";
        endpoint_url = "http://127.0.0.1:10001";
      };
    };
  };
}
