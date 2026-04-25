import json
import os
import signal
import subprocess
import sys
import tempfile
import time

SS2022_METHOD = "2022-blake3-aes-128-gcm"
FAILOVER_INTERVAL = 300

PADDING_SCHEME = [
    "stop=8",
    "0=380-620",
    "1=600-950",
    "2=1200-1400,c,200-500,c,400-800",
    "3=64-128,c,1100-1400",
    "4=1100-1400",
    "5=80-200,c,1100-1400",
    "6=1100-1400",
    "7=1100-1400",
]

CONFIG_PATH = os.environ["LADDER_MANAGER_CONFIG"]

with open(CONFIG_PATH, "r", encoding="utf-8") as f:
    CFG = json.load(f)

ANYTLS_PORT = CFG["ports"]["anytls"]
SS2022_PORT = CFG["ports"]["ss2022"]
SNELL_PORT = CFG["ports"]["snell"]
BIND_INTERFACE = CFG.get("bindInterface", "eth0")

procs = []
stopping = False


def log(message):
    print(f"ladder-manager: {message}", flush=True)


def run(*args, check=True):
    return subprocess.run(args, check=check)


def run_quiet(*args, check=True):
    return subprocess.run(
        args,
        check=check,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def read_password():
    with open(CFG["passwordFile"], "r", encoding="utf-8") as f:
        return f.readline().rstrip("\r\n")


def ensure_cert():
    os.makedirs(CFG["stateDir"], mode=0o700, exist_ok=True)
    if os.path.exists(CFG["certPath"]) and os.path.exists(CFG["keyPath"]):
        return

    log("generating self-signed AnyTLS certificate")
    ecparam = subprocess.check_output(
        [CFG["commands"]["openssl"], "ecparam", "-name", "prime256v1"]
    )
    ecparam_path = os.path.join(CFG["stateDir"], "ecparam.pem")
    with open(ecparam_path, "wb") as f:
        f.write(ecparam)

    try:
        run(
            CFG["commands"]["openssl"],
            "req",
            "-x509",
            "-newkey",
            f"ec:{ecparam_path}",
            "-keyout",
            CFG["keyPath"],
            "-out",
            CFG["certPath"],
            "-days",
            "36500",
            "-nodes",
            "-subj",
            "/CN=cname.vercel-dns.com",
        )
    finally:
        try:
            os.unlink(ecparam_path)
        except FileNotFoundError:
            pass

    os.chmod(CFG["keyPath"], 0o400)
    os.chmod(CFG["certPath"], 0o444)


def can_ping(ip):
    result = subprocess.run(
        [CFG["commands"]["ping"], "-I", BIND_INTERFACE, "-c", "3", "-W", "3", ip],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def active_exit_ip(current=None):
    for exit_ip in CFG["exits"]:
        if can_ping(exit_ip):
            return exit_ip
    return current or CFG["exits"][0]


def base_config():
    return {
        "log": {"disabled": False, "level": "warn"},
        "dns": {"servers": [{"type": "local", "tag": "local"}]},
    }


def anytls_inbound(password):
    return {
        "type": "anytls",
        "listen": "::",
        "listen_port": ANYTLS_PORT,
        "tcp_multi_path": True,
        "users": [{"name": "default", "password": password}],
        "padding_scheme": PADDING_SCHEME,
        "tls": {
            "enabled": True,
            "certificate_path": CFG["certPath"],
            "key_path": CFG["keyPath"],
        },
    }


def direct_outbound():
    return {
        "type": "direct",
        "tag": "direct",
        "tcp_multi_path": True,
        "domain_resolver": {"server": "local", "strategy": "prefer_ipv6"},
    }


def write_exit_singbox_config(password):
    config = base_config()
    config.update(
        {
            "inbounds": [
                {
                    "type": "shadowsocks",
                    "listen": "::",
                    "listen_port": SS2022_PORT,
                    "tcp_multi_path": True,
                    "method": SS2022_METHOD,
                    "password": password,
                },
                anytls_inbound(password),
            ],
            "outbounds": [direct_outbound()],
            "route": {
                "rules": [
                    {"action": "sniff"},
                    {
                        "protocol": ["bittorrent"],
                        "action": "reject",
                        "method": "default",
                    },
                ],
                "final": "direct",
            },
        }
    )
    write_json(CFG["singboxConfigPath"], config)


def write_snell_config(password):
    snell_config = "\n".join(
        [
            "[snell-server]",
            f"listen = ::0:{SNELL_PORT}",
            f"psk = {password}",
            "ipv6 = true",
            "",
        ]
    )
    write_text(CFG["snellConfigPath"], snell_config)


def write_relay_configs(active_ip, password):
    config = base_config()
    config.update(
        {
            "inbounds": [
                anytls_inbound(password),
            ],
            "outbounds": [
                direct_outbound(),
                {
                    "type": "shadowsocks",
                    "tag": "ss2022-out",
                    "server": active_ip,
                    "server_port": SS2022_PORT,
                    "method": SS2022_METHOD,
                    "password": password,
                    "tcp_multi_path": True,
                    "bind_interface": BIND_INTERFACE,
                    "domain_resolver": {"server": "local", "strategy": "prefer_ipv6"},
                },
            ],
            "route": {
                "auto_detect_interface": True,
                "rules": [
                    {"action": "sniff"},
                    {
                        "protocol": ["bittorrent"],
                        "action": "reject",
                        "method": "default",
                    },
                ],
                "final": "ss2022-out",
            },
        }
    )

    write_json(CFG["singboxConfigPath"], config)
    write_snell_config(password)


def write_json(path, value):
    directory = os.path.dirname(path)
    fd, tmp_path = tempfile.mkstemp(dir=directory, prefix=f".{os.path.basename(path)}.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(value, f, indent=2)
        f.write("\n")
    os.chmod(tmp_path, 0o400)
    os.replace(tmp_path, path)


def write_text(path, value):
    directory = os.path.dirname(path)
    fd, tmp_path = tempfile.mkstemp(dir=directory, prefix=f".{os.path.basename(path)}.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(value)
    os.chmod(tmp_path, 0o440)
    os.replace(tmp_path, path)


def start_singbox():
    run(CFG["commands"]["singBox"], "check", "-c", CFG["singboxConfigPath"])
    proc = subprocess.Popen(
        [CFG["commands"]["singBox"], "run", "-c", CFG["singboxConfigPath"]]
    )
    procs.append(proc)
    return proc


def start_snell():
    proc = subprocess.Popen(
        [CFG["commands"]["snellServer"], "-c", CFG["snellConfigPath"]]
    )
    procs.append(proc)
    return proc


def start_exit():
    password = read_password()
    write_exit_singbox_config(password)
    write_snell_config(password)
    start_singbox()
    start_snell()
    log("started exit node with direct Snell")


def start_relay(active_ip):
    password = read_password()
    write_relay_configs(active_ip, password)
    start_singbox()
    start_snell()
    log(
        f"started relay node with ss2022 outbound {active_ip}:{SS2022_PORT} "
        "and direct Snell"
    )


def stop_processes():
    for proc in reversed(procs):
        if proc.poll() is None:
            proc.terminate()

    deadline = time.monotonic() + 3
    for proc in reversed(procs):
        remaining = max(0.1, deadline - time.monotonic())
        try:
            proc.wait(timeout=remaining)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
    procs.clear()


def handle_signal(signum, frame):
    global stopping
    stopping = True
    stop_processes()


def monitor_children():
    for proc in procs:
        if proc.poll() is not None:
            stop_processes()
            return proc.returncode or 1
    return None


def run_exit():
    start_exit()
    while not stopping:
        exit_code = monitor_children()
        if exit_code is not None:
            return exit_code
        time.sleep(1)
    return 0


def run_relay():
    active = active_exit_ip()
    start_relay(active)

    while not stopping:
        exit_code = monitor_children()
        if exit_code is not None:
            return exit_code

        next_active = active_exit_ip(active)
        if next_active != active:
            log(f"switching ss2022 outbound {active} -> {next_active}")
            stop_processes()
            active = next_active
            start_relay(active)

        time.sleep(FAILOVER_INTERVAL)

    return 0


def main():
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)
    ensure_cert()

    if CFG["role"] == "exit":
        return run_exit()
    return run_relay()


if __name__ == "__main__":
    sys.exit(main())
