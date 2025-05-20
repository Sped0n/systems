{...}: {
  disko = {
    devices = {
      disk = {
        my-disk = {
          device = "/dev/vda";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                size = "1M";
                type = "EF02";
                priority = 0;
              };

              ESP = {
                type = "EF00";
                size = "500M";
                priority = 1;
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = ["fmask=0077" "dmask=0077"];
                };
              };

              nix = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "btrfs";
                  mountpoint = "/";
                  mountOptions = ["compress-force=zstd" "nosuid" "nodev"];
                };
              };
            };
          };
        };
      };
    };
  };
}
