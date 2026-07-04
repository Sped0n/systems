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
    containerBin
    enabledArches
    keyPath
    launchAgentsDir
    pubKeyPath
    runAsUser
    runtimeLabel
    stateDir
    user
    userHome
    ;
  inherit (myLinuxBuilderLaunchd) builderPlists runtimePlist;
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
    } // lib.mapAttrs' (_: arch: lib.nameValuePair "ssh/ssh_config.d/100-${arch.name}.conf" {
      text = ''
        Host ${arch.name}
          HostName localhost
          Port ${toString arch.port}
          User root
          IdentityFile ${keyPath}
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
      '';
    }) enabledArches;

    system.defaults.CustomUserPreferences."com.apple.container.defaults"."dns.domain" = "test";

    system.activationScripts.preActivation.text = lib.mkAfter ''
      set -euo pipefail

      macos_major=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}')
      if [ "$macos_major" -lt 26 ]; then
        echo "services.my-linux-builder requires macOS 26+ when x86_64-linux uses Apple container's default Rosetta kernel" >&2
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
      ${lib.concatStrings (lib.mapAttrsToList (_: spec: ''
        install -o root -g wheel -m 644 ${spec.plist} ${spec.path}
      '') builderPlists)}

      if ! ${runAsUser} ${containerBin} system status >/dev/null 2>&1; then
        ${runAsUser} ${containerBin} system start --disable-kernel-install
      fi

      KERNEL_DIR=${lib.escapeShellArg "${appSupport}/kernels"}
      if [ ! -e "$KERNEL_DIR/default.kernel-arm64" ]; then
        ${runAsUser} ${containerBin} system kernel set --recommended
      fi

      ${runAsUser} ${containerBin} prune >/dev/null 2>&1 || true
    '';

    system.activationScripts.postActivation.text = lib.mkAfter ''
      set -euo pipefail

      CONTAINER_UID=$(id -u ${lib.escapeShellArg user})
      domain="user/$CONTAINER_UID"
      launchctl print "$domain" >/dev/null 2>&1 || exit 0
      launchctl bootout "$domain/${runtimeLabel}" 2>/dev/null || true
      launchctl bootstrap "$domain" ${launchAgentsDir}/${runtimeLabel}.plist 2>/dev/null || true
      launchctl enable "$domain/${runtimeLabel}" >/dev/null 2>&1 || true
      ${lib.concatStrings (lib.mapAttrsToList (_: spec: ''
        launchctl bootout "$domain/${spec.label}" 2>/dev/null || true
        launchctl bootstrap "$domain" ${spec.path} 2>/dev/null || true
        launchctl enable "$domain/${spec.label}" >/dev/null 2>&1 || true
      '') builderPlists)}
    '';
  };
}
