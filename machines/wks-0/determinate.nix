{ ... }:
{
  determinateNix = {
    customSettings.extra-experimental-features = "external-builders";
    determinateNixd.builder = {
      state = "enabled";
      memoryBytes = 12884901888;
    };
  };
}
