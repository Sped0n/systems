{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation {
  pname = "espressif-udev";
  version = "0.12.0-esp32-20260831";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/espressif/openocd-esp32/v0.12.0-esp32-20260831/contrib/60-openocd.rules";
    hash = "sha256-7z/zX1cYr2zS0+BGtdfw3sMXpLhAzTpDCT06ZOvx1rE=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 $src $out/lib/udev/rules.d/60-openocd.rules
    runHook postInstall
  '';

  meta = {
    description = "Espressif OpenOCD udev rules for USB debug adapters";
    homepage = "https://github.com/espressif/openocd-esp32";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
