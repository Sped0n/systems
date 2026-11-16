{ ... }:
final: prev:
let
  jlinkOverrides = {
    acceptLicense = true;
    fetchurl =
      args:
      (prev.fetchurl args).overrideAttrs (old: {
        # Work around https://github.com/NixOS/nixpkgs/issues/580434.
        builder = final.writeText "fetchurl-without-resume.sh" (
          final.lib.replaceStrings [ "--continue-at -" "-C -" ] [ "" "" ] (builtins.readFile old.builder)
        );
      });
  };
in
{
  segger-jlink = prev.segger-jlink.override jlinkOverrides;
  segger-jlink-headless = prev.segger-jlink-headless.override jlinkOverrides;

  # nixpkgs' headless variant omits every executable; the full variant pulls
  # in insecure Qt 4. Keep Commander and its device data without the GUI tools.
  segger-jlink-cli = final.segger-jlink-headless.overrideAttrs (old: {
    meta = old.meta // {
      platforms = final.lib.intersectLists final.lib.platforms.linux old.meta.platforms;
    };
    postInstall = (old.postInstall or "") + ''
      install -Dm755 JLinkExe -t $out/opt/SEGGER/JLink
      # Default patchelf relocation overlaps a read-only LOAD segment in
      # Commander, causing the dynamic loader to segfault before main().
      patchelf --page-size 65536 \
        --set-interpreter ${final.stdenv.cc.bintools.dynamicLinker} \
        $out/opt/SEGGER/JLink/JLinkExe
      cp -r ETC Firmwares $out/opt/SEGGER/JLink/
      mkdir -p $out/bin
      ln -s $out/opt/SEGGER/JLink/JLinkExe $out/bin/JLinkExe
    '';
  });
}
