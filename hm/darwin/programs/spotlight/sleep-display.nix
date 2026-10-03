{ pkgs, ... }:
let
  name = "sleep-display";
  launcher = pkgs.writeShellApplication {
    inherit name;
    text = ''
      /usr/bin/pmset displaysleepnow
    '';
  };
in
{
  home.packages = [
    (pkgs.runCommand "${name}-app" { } ''
      mkdir -p "$out/bin"
      cp ${launcher}/bin/${name} "$out/bin/${name}"
      source ${
        pkgs.makeDarwinBundle {
          inherit name;
          exec = name;
        }
      }
      makeDarwinBundlePhase
    '')
  ];
}
