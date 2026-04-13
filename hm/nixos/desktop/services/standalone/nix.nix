{
  config,
  functions,
  lib,
  vars,
  ...
}:
let
  standalone = config.services.standalone;
in
{
  config = lib.mkIf standalone.enable (
    import (functions.fromRoot "/modules/shared/nix/settings.nix") { inherit vars; }
  );
}
