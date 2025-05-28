{
  pkgs,
  username,
  ...
}: {
  users.groups = {
    dialout = {};
    plugdev = {};
  };

  users.users."${username}" = {
    extraGroups = [
      "dialout"
      "plugdev"
    ];
  };

  services.udev = {
    packages = [pkgs.openocd];
    extraRules =
      # Espressif USB JTAG/serial debug units
      ''
        ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", MODE="660", GROUP="plugdev", TAG+="uaccess"
        ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1002", MODE="660", GROUP="plugdev", TAG+="uaccess"
      '';
  };
}
