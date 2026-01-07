# Deploy from Scratch

## How-tos

### Get Hardware Configuration from Non-NixOS Host

> [!NOTE]
> Nix is not SELinux compatible.
> So it is better to choose a debian based distro (e.g., Ubuntu) to perform the steps below.

First install Nix on the host with:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

Then exit the terminal and open a new one. Run:

```bash
nix-env -iE "_: with import <nixpkgs/nixos> { configuration = {}; }; \
  with config.system.build; [ nixos-generate-config ]"
nixos-generate-config --no-filesystems --root /tmp
```

You will find the hardware configuration file under `/tmp/etc/nixos/hardware-configuration.nix`.

### Perform Installation on Systems with Limited RAM

> [!NOTE]
> System need to have at least 1GB of RAM, or OOM might occur during installation.

After we enter nixos-installer after kexec, we can use below command to create a zram swap device:

```
zramctl /dev/zram0 --algorithm zstd --size "$(($(grep -Po 'MemTotal:\s*\K\d+' /proc/meminfo)/2))KiB"
mkswap -U clear /dev/zram0
swapon --discard --priority 100 /dev/zram0
```

## Steps

### macOS

1. Copy SSH host key (pubkey) to `secrets` flake and set the correct permissions.
   - You can generate the SSH host key pair with `sudo ssh-keygen -A` if you don't have one.
2. Use `ssh-keygen -t ed25519` to generate a temporary key pair.
3. Add the temporary key to the ssh-agent with `eval '$(ssh-agent -s)' && ssh-add ~/.ssh/id_ed25519`.
4. Add the temporary key (pubkey) to the GitHub.
   - Settings > SSH and GPG keys > New SSH key.
5. Clone the repo with `git clone git@github.com:Sped0n/systems.git`.
   - Run the command under `/Users/spedon/.config`.
6. Install Nix (not Determinate Nix) with [determinate nix installer](https://github.com/DeterminateSystems/nix-installer).
7. Run `sudo nix run nix-darwin/nix-darwin-25.05#darwin-rebuild -- switch .#<configuration name>`.
   - Change 25.05 to the latest stable version.
   - Change `<configuration name>` to the hostname of the machine you are deploying to.
   - Run the command under `/Users/spedon/.config/systems`.
8. You are good to go!
9. Remove the temporary key from the GitHub.

### NixOS (server)

1. Get below information from the VPS.
   - The IPv4/IPv6 address and gateway (`ip addr && ip route show default && ip -6 route show default`).
   - The [hardware configuration](#get-hardware-configuration-from-non-nixos-host).
   - The SSH host key (`cat /etc/ssh/ssh_host_ed25519_key.pub`).
2. Modify the configuration files under `machines/<configuration name>/` accordingly.
3. Copy the SSH host key (pubkey) to `secrets` flake and set the correct permissions.
4. Run

   ```
   nixos-anywhere \
      --flake .#<configuration name> \
      --kexec "$(nix build --print-out-paths github:Sped0n/nixos-images#packages.<arch>-linux.kexec-installer-nixos-unstable-noninteractive)/nixos-kexec-installer-noninteractive-<arch>-linux.tar.gz" \
      --copy-host-keys \
      --no-disko-deps \
      --target-host root@<ip address> \
      --ssh-option "PubkeyAuthentication=no"
   ```

   - Change `<configuration name>` to the hostname of the machine you are deploying to.
   - Change `<arch>` to `x86_64` or `aarch64` depending on the architecture of the VPS.
   - Change `<ip address>` to the public IPv4 address of the VPS.
   - User need to have a nix environment to run this command.
   - Run the command under `/Users/spedon/.config/systems`.

5. Key in the root password (several times).
   - This is the original password before kexec.
6. After server kexec into nixos-installer, use below two ways to set a default password for root user.
   - Use VNC provided by the VPS provider and run `passwd` command.
   - Direct SSH (`ssh root@<ip address> -o PubkeyAuthentication=no`) and run `passwd` command.
7. [Setup zram](#perform-installation-on-systems-with-limited-ram) if needed.
8. Key in the root password (several times).
   - This is the new password set in step 7.
9. Wait for the command to finish.
10. You are good to go!

### NixOS (desktop)

1. Download the ISO from [NixOS download page](https://nixos.org/download).
2. Boot from the ISO.
3. Skip the graphical installer and open console.
4. Run `sudo su` to switch to root.
5. Repeat step 1 to 4 of [macOS](#macos).
6. Clone the repo with `git clone git@github.com:Sped0n/systems.git`.
   - Run the command under `/tmp`.
7. Find where the target configuration's `disko.nix` located and run `sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount <path to disko.nix>`
8. Run `nixos-generate-config --no-filesystems --root /mnt`
9. Move the repo to with `mv /tmp/systems /mnt/etc/nixos`.
10. Place the agenix identity key to `/mnt/etc/nixos/id_agenix`.
    - `chmod` the key to 0500.
11. Run `nixos-install --flake .#<configuration name>`.
    - Change `<configuration name>` to the hostname of the machine you are deploying to.
    - Run the command under `/mnt/etc/nixos`.
12. Reboot.
13. You are good to go!
14. Remove the temporary key from the GitHub.
