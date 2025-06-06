{...}: {
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
