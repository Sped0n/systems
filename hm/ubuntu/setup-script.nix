{
  lib,
  pkgs,
  name,
  description,
  script,
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
  description=${lib.escapeShellArg description}
  ${builtins.readFile script}
  ${builtins.readFile ./scripts/setup-script.sh}
''
