{ pkgs, ... }:
let
  name = "eject-all";
  launcher = pkgs.writeShellApplication {
    inherit name;
    text = ''
      /usr/bin/osascript <<'APPLESCRIPT'
      tell application "Finder"
        set ejectableDisks to every disk whose ejectable is true
        set failures to {}
        repeat with mountedDisk in ejectableDisks
          set diskName to name of mountedDisk
          try
            eject mountedDisk
          on error errorMessage
            set end of failures to diskName & ": " & errorMessage
          end try
        end repeat
      end tell

      if (count of failures) > 0 then
        set AppleScript's text item delimiters to linefeed
        display alert "Some disks could not be ejected" message (failures as text) as warning
      else if (count of ejectableDisks) > 0 then
        display notification "Ejectable disks were ejected." with title "eject-all"
      else
        display notification "No ejectable disks found." with title "eject-all"
      end if
      APPLESCRIPT
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
