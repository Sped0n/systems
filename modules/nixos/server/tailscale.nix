{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  vars,
  ...
}:
let
  my-docker = config.services.my-docker;
  my-telegraf = config.services.my-telegraf;
  dockerAddressPools = config.virtualisation.docker.daemon.settings."default-address-pools" or [ ];

  dockerSubnets = map (pool: pool.base) dockerAddressPools;
in
{
  services.tailscale = {
    enable = true;
    package = pkgs-unstable.tailscale;
    interfaceName = "tailscale0";
    openFirewall = true;
  };

  services.my-telegraf.extraConfig = lib.mkIf my-telegraf.enable {
    inputs.prometheus = [
      {
        urls = [ "http://100.100.100.100/metrics" ];
        namepass = [
          "tailscaled_inbound_bytes_total"
          "tailscaled_outbound_bytes_total"
        ];
        tagexclude = [ "url" ];
        timeout = "5s";
      }
    ];

    outputs.influxdb = [
      {
        urls = [ "http://srv-de-0.${vars.tailnet}:8428" ];
        database = "victoriametrics";
        skip_database_creation = true;
        exclude_retention_policy_tag = true;
        content_encoding = "gzip";
        namepass = [
          "tailscaled_inbound_bytes_total"
          "tailscaled_outbound_bytes_total"
        ];
      }
    ];
  };

  services.my-telegraf.syslogExtraFilters.ignore_tailscaled_noise = lib.mkIf my-telegraf.enable ''
    not (
      program("tailscaled") and
      level(info) and
      (
        message("(derphttp\\.Client\\.(Recv|Send): connecting to derp-|magicsock:|netcheck:|wgengine:|dns:|router:|LinkChange:|Rebind;|DetectCaptivePortal\\(|netmap: suggested exit node:|post-rebind ping of DERP region|writing netmap to disk cache)") or
        message("control: (controlclient direct:|NetInfo:|netmap:|sleeping for server-requested)") or
        message("health\\(warnable=.*\\): ok") or
        message("logtail: (bootstrap dial succeeded|upload succeeded after)") or
        message("\\[RATELIMIT\\] format\\(\"(%s: connecting to derp-%d|health\\(warnable=%s\\): ok|magicsock: derp-%d|post-rebind ping of DERP region %d okay)")
      )
    );
  '';

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # https://tailscale.com/s/ethtool-config-udp-gro
  system.activationScripts."tailscale-udp-gro-forwarding".text = ''
    ${pkgs.ethtool}/bin/ethtool -K eth0 rx-udp-gro-forwarding on rx-gro-list off
  '';

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
  }
  // lib.optionalAttrs my-docker.enable {
    extraCommands = lib.concatMapStringsSep "\n" (subnet: ''
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${subnet} -o tailscale0 -j MASQUERADE
    '') dockerSubnets;
    extraStopCommands = lib.concatMapStringsSep "\n" (subnet: ''
      ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${subnet} -o tailscale0 -j MASQUERADE || true
    '') dockerSubnets;
  };
}
