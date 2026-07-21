{
  lib,
  stdenv,
  fetchurl,
  xar,
  cpio,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "apple-container";
  version = "1.1.0";

  src = fetchurl {
    url = "https://github.com/apple/container/releases/download/${finalAttrs.version}/container-${finalAttrs.version}-installer-signed.pkg";
    hash = "sha256-DKHEKiJpwlV++x2CsbOKxVPmo6PaGxF5xDm87h59ZxQ=";
  };

  nativeBuildInputs = [
    xar
    cpio
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    xar -xf $src
    gunzip -dc Payload | cpio -i
  '';

  installPhase = ''
    mkdir -p $out/bin $out/libexec
    cp -a bin/container bin/container-apiserver $out/bin/
    cp -a libexec/container $out/libexec/
  '';

  # Apple-signed binaries: strip/fixup breaks code signatures.
  dontFixup = true;

  meta = {
    description = "Apple's native container runtime";
    homepage = "https://github.com/apple/container";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "container";
  };
})
