{ lib, ... }:
{
  nix.gc = {
    automatic = true;
    interval = lib.mkDefault [
      {
        Weekday = 0;
        Hour = 0;
        Minute = 0;
      }
    ];
    options = lib.mkDefault "--delete-older-than 30d";
  };
}
