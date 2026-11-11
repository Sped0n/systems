{
  config,
  lib,
  pkgs,
  name,
  description,
  script,
  variables ? { },
}:
pkgs.writeShellScript name ''
  export PATH=${
    lib.makeBinPath [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.iproute2
      pkgs.procps
    ]
  }:/usr/sbin:/usr/bin:/sbin:/bin
  ${config.lib.bash.initHomeManagerLib}
  description=${lib.escapeShellArg description}
  ${lib.toShellVars variables}
  ${builtins.readFile script}
  ${builtins.readFile ./scripts/setup-script.sh}
''
