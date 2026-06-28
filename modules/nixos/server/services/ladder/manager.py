import json
import os
import signal
import subprocess
import sys
import tempfile
import time

SS2022_METHOD = "2022-blake3-aes-128-gcm"
URLTEST_TAG = "ss2022-auto"
URLTEST_INTERVAL = "30s"

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

singbox_proc = None
snell_proc = None
stopping = False


def log(message):
    print(f"ladder-manager: {message}", flush=True)


def run(*args, check=True):
    return subprocess.run(args, check=check)


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


def ss2022_inbound(password):
    return {
        "type": "shadowsocks",
        "listen": "::",
        "listen_port": SS2022_PORT,
        "tcp_multi_path": True,
        "method": SS2022_METHOD,
        "password": password,
    }


def direct_outbound():
    return {
        "type": "direct",
        "tag": "direct",
        "tcp_multi_path": True,
        "domain_resolver": {"server": "local", "strategy": "prefer_ipv6"},
    }


def ss2022_outbound(tag, server, password):
    return {
        "type": "shadowsocks",
        "tag": tag,
        "server": server,
        "server_port": SS2022_PORT,
        "method": SS2022_METHOD,
        "password": password,
        "tcp_multi_path": True,
        "bind_interface": BIND_INTERFACE,
        "domain_resolver": {"server": "local", "strategy": "prefer_ipv6"},
    }


def urltest_outbound(tags):
    return {
        "type": "urltest",
        "tag": URLTEST_TAG,
        "outbounds": tags,
        "url": "https://www.gstatic.com/generate_204",
        "interval": URLTEST_INTERVAL,
        "tolerance": 50,
        "interrupt_exist_connections": False,
    }


def write_exit_singbox_config(password):
    config = base_config()
    config.update(
        {
            "inbounds": [
                ss2022_inbound(password),
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


def write_relay_singbox_config(password):
    outbound_tags = [f"ss2022-out-{index}" for index, _ in enumerate(CFG["exits"])]
    config = base_config()
    config.update(
        {
            "inbounds": [
                anytls_inbound(password),
                ss2022_inbound(password),
            ],
            "outbounds": [
                direct_outbound(),
                *[
                    ss2022_outbound(tag, exit_ip, password)
                    for tag, exit_ip in zip(outbound_tags, CFG["exits"])
                ],
                urltest_outbound(outbound_tags),
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
                "final": URLTEST_TAG,
            },
        }
    )

    write_json(CFG["singboxConfigPath"], config)


def write_relay_configs(password):
    write_relay_singbox_config(password)
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
    global singbox_proc
    run(CFG["commands"]["singBox"], "check", "-c", CFG["singboxConfigPath"])
    singbox_proc = subprocess.Popen(
        [CFG["commands"]["singBox"], "run", "-c", CFG["singboxConfigPath"]]
    )
    return singbox_proc


def start_snell():
    global snell_proc
    snell_proc = subprocess.Popen(
        [CFG["commands"]["snellServer"], "-c", CFG["snellConfigPath"]]
    )
    return snell_proc


def start_exit():
    password = read_password()
    write_exit_singbox_config(password)
    write_snell_config(password)
    start_singbox()
    start_snell()
    log("started exit node with direct Snell")


def start_relay():
    password = read_password()
    write_relay_configs(password)
    start_singbox()
    start_snell()
    log(
        f"started relay node with urltest over {len(CFG['exits'])} ss2022 outbounds "
        "and direct Snell"
    )


def stop_process(proc):
    if proc is None:
        return
    if proc.poll() is None:
        proc.terminate()
    deadline = time.monotonic() + 3
    remaining = max(0.1, deadline - time.monotonic())
    try:
        proc.wait(timeout=remaining)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()


def stop_singbox():
    global singbox_proc
    stop_process(singbox_proc)
    singbox_proc = None


def stop_snell():
    global snell_proc
    stop_process(snell_proc)
    snell_proc = None


def stop_processes():
    stop_singbox()
    stop_snell()


def handle_signal(signum, frame):
    global stopping
    stopping = True
    stop_processes()


def restart_exited_children():
    restarted = False
    if singbox_proc is not None and singbox_proc.poll() is not None:
        log(f"sing-box exited with status {singbox_proc.returncode}; restarting")
        start_singbox()
        restarted = True
    if snell_proc is not None and snell_proc.poll() is not None:
        log(f"snell-server exited with status {snell_proc.returncode}; restarting")
        start_snell()
        restarted = True
    return restarted


def run_exit():
    start_exit()
    while not stopping:
        restart_exited_children()
        time.sleep(1)
    return 0


def run_relay():
    start_relay()

    while not stopping:
        restart_exited_children()
        time.sleep(1)

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
