{...}: {
  security.rtkit.enable = true;
  services = {
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      extraConfig.pipewire."hires" = {
        "context.properties" = {
          "default.clock.allowed-rates" = [44100 48000 88200 96000 176400 192000 352800 384000];
        };
        "stream.properties" = {
          "resample.quality" = 14;
        };
      };
    };
  };
}
