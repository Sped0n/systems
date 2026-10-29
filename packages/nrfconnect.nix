{
  lib,
  fetchurl,
  appimageTools,
  segger-jlink-cli,
}:
let
  pname = "nrfconnect";
  version = "5.4.0";

  src = fetchurl {
    url = "https://github.com/nordicsemi/pc-nrfconnect-launcher/releases/download/v${version}/nrfconnect-${version}-x86_64.AppImage";
    hash = "sha256-kCibGB8SEdjlGau2VwPQlzlj+gF02UI76UxmEUgz5Vo=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # The headless package contains libjlinkarm, but not JLinkExe, which the
  # launcher invokes to detect an existing installation (including from a GUI).
  extraPkgs = pkgs: [ segger-jlink-cli ];
  profile = ''
    export PATH=${lib.makeBinPath [ segger-jlink-cli ]}:"$PATH"
  '';

  extraInstallCommands = ''
    mkdir -p $out/lib/udev/rules.d
    cp ${segger-jlink-cli}/lib/udev/rules.d/99-jlink.rules $out/lib/udev/rules.d/
    cat >$out/lib/udev/rules.d/71-nrf.rules <<'EOF'
    ACTION!="add", GOTO="nrf_rules_end"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="1915", MODE="0666"
    KERNEL=="ttyACM[0-9]*", SUBSYSTEM=="tty", SUBSYSTEMS=="usb", ATTRS{idVendor}=="1915", MODE="0666", ENV{NRF_CDC_ACM}="1"
    LABEL="nrf_rules_end"
    EOF
    cat >$out/lib/udev/rules.d/99-mm-nrf-blacklist.rules <<'EOF'
    ENV{NRF_CDC_ACM}=="1", ENV{ID_MM_CANDIDATE}="0", ENV{ID_MM_DEVICE_IGNORE}="1"
    EOF

    install -Dm444 ${appimageContents}/nrfconnect.desktop -t $out/share/applications
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/nrfconnect.png \
      -t $out/share/icons/hicolor/512x512/apps
    substituteInPlace $out/share/applications/nrfconnect.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=nrfconnect'
  '';

  meta = {
    description = "Nordic Semiconductor nRF Connect for Desktop";
    homepage = "https://www.nordicsemi.com/Products/Development-tools/nRF-Connect-for-desktop";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "nrfconnect";
  };
}
