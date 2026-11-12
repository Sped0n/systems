{
  config,
  secrets,
  vars,
  ...
}:
{
  age.secrets = with vars; {
    "openwrt-ssh-key" = {
      file = "${secrets}/ages/openwrt-ssh-key.age";
      mode = "0400";
      path = "${home}/.ssh/id_openwrt";
    };
  };

  programs.ssh.settings = {
    "openwrt-CHIP" = {
      hostname = "192.168.31.1";
      port = 12222;
      user = "root";
      identityFile = config.age.secrets."openwrt-ssh-key".path;
    };
  };
}
