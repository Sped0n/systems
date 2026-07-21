{ lib, ... }:
{
  options.services.my-linux-builder = {
    enable = lib.mkEnableOption "Apple-container Linux builders";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/sped0n/darwin-builder:latest";
      description = "Builder OCI image.";
    };

    cores = lib.mkOption {
      type = lib.types.ints.positive;
      default = 6;
      description = "CPU cores allocated to each builder container.";
    };

    memory = lib.mkOption {
      type = lib.types.str;
      default = "8192M";
      description = "Memory allocated to each builder container.";
    };

    maxJobs = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Maximum concurrent Nix jobs scheduled on each builder.";
    };

    ephemeral = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Remove each builder container before starting it, giving it a fresh root filesystem.";
    };

    idleTimeout = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 60 * 60;
      description = "Stop a builder container after this many seconds without an established SSH connection. Set to null to disable.";
    };

    pruneOldImages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Remove old local tags for the configured builder image repository during activation.";
    };
  };
}
