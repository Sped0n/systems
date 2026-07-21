{
  config,
  lib,
  pkgs,
  myLinuxBuilderLaunchd,
  ...
}:
let
  cfg = config.services.my-linux-builder;
  common = import ./lib.nix { inherit config lib pkgs; };
  keys = import ./keys.nix { inherit pkgs; };
  inherit (common)
    appSupport
    builder
    containerBin
    keyPath
    launchAgentsDir
    pubKeyPath
    runAsUser
    runtimeLabel
    stateDir
    user
    userHome
    ;
  inherit (myLinuxBuilderLaunchd) builderPlist runtimePlist runtimeScript;
in
{
  imports = [
    ./options.nix
    ./cli.nix
    ./launchd.nix
    ./nix.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isDarwin;
        message = "services.my-linux-builder uses Apple container and requires aarch64-darwin.";
      }
    ];

    environment.systemPackages = [ pkgs.apple-container ];

    environment.etc = {
      "resolver/containerization.test".text = ''
        domain test
        search test
        nameserver 127.0.0.1
        port 2053
      '';
      "ssh/ssh_config.d/100-${builder.name}.conf".text = ''
        Host ${builder.name}
          HostName localhost
          Port ${toString builder.port}
          User root
          IdentityFile ${keyPath}
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
      '';
    };

    system.defaults.CustomUserPreferences."com.apple.container.defaults"."dns.domain" = "test";

    system.activationScripts.preActivation.text = lib.mkAfter ''
      set -euo pipefail

      macos_major=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}')
      if [ "$macos_major" -lt 26 ]; then
        echo "services.my-linux-builder requires macOS 26+" >&2
        exit 1
      fi

      install -d -m 700 -o ${lib.escapeShellArg user} ${lib.escapeShellArg "${userHome}/.ssh"}
      install -o ${lib.escapeShellArg user} -m 600 ${keys.privateKey} ${lib.escapeShellArg keyPath}
      install -o ${lib.escapeShellArg user} -m 644 ${keys.publicKey} ${lib.escapeShellArg pubKeyPath}

      launchctl bootout system/org.nixos.linux-builder 2>/dev/null || true
      rm -f /Library/LaunchDaemons/org.nixos.linux-builder.plist

      install -d -m 755 -o root -g wheel ${launchAgentsDir}
      install -d -m 1777 ${stateDir}
      install -o root -g wheel -m 644 ${runtimePlist} ${launchAgentsDir}/${runtimeLabel}.plist
      install -o root -g wheel -m 644 ${builderPlist.plist} ${builderPlist.path}
      rm -f \
        ${launchAgentsDir}/dev.apple.container.darwin-builder-aarch64.plist \
        ${launchAgentsDir}/dev.apple.container.darwin-builder-x86_64.plist

      if ! ${runAsUser} ${containerBin} system status >/dev/null 2>&1; then
        ${runAsUser} ${containerBin} system start --disable-kernel-install
      fi

      KERNEL_DIR=${lib.escapeShellArg "${appSupport}/kernels"}
      if [ ! -e "$KERNEL_DIR/default.kernel-arm64" ]; then
        ${runAsUser} ${containerBin} system kernel set --recommended
      fi

      ${runAsUser} ${containerBin} prune >/dev/null 2>&1 || true
      ${lib.optionalString cfg.pruneOldImages ''
        image_ref=${lib.escapeShellArg cfg.image}
        image_name="''${image_ref%:*}"
        image_tag="''${image_ref##*:}"
        if [ "$image_name" != "$image_ref" ]; then
          ${runAsUser} ${containerBin} image ls \
            | /usr/bin/awk -v name="$image_name" -v keep="$image_tag" 'NR > 1 && $1 == name && $2 != keep { print $1 ":" $2 }' \
            | while IFS= read -r stale_image; do
                [ -n "$stale_image" ] || continue
                ${runAsUser} ${containerBin} image rm "$stale_image" >/dev/null 2>&1 || true
              done
        fi
      ''}
    '';

    system.activationScripts.postActivation.text = lib.mkAfter ''
      set -euo pipefail

      CONTAINER_UID=$(id -u ${lib.escapeShellArg user})
      domain="user/$CONTAINER_UID"
      launchctl print "$domain" >/dev/null 2>&1 || exit 0
      for old_builder in darwin-builder-aarch64 darwin-builder-x86_64; do
        launchctl bootout "$domain/dev.apple.container.$old_builder" 2>/dev/null || true
        ${runAsUser} ${containerBin} stop "$old_builder" >/dev/null 2>&1 || true
        ${runAsUser} ${containerBin} rm "$old_builder" >/dev/null 2>&1 || true
      done
      launchctl bootout "$domain/${builderPlist.label}" 2>/dev/null || true
      launchctl bootout "$domain/${runtimeLabel}" 2>/dev/null || true
      ${runAsUser} ${runtimeScript}
      launchctl bootstrap "$domain" ${launchAgentsDir}/${runtimeLabel}.plist
      launchctl enable "$domain/${runtimeLabel}" >/dev/null 2>&1 || true
      launchctl bootstrap "$domain" ${builderPlist.path} 2>/dev/null || true
      launchctl enable "$domain/${builderPlist.label}" >/dev/null 2>&1 || true
    '';
  };
}
