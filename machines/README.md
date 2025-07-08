# Machines

## Deploy from scratch

### macOS

1. Place the agenix identity key to `/Users/spedon/.config/secrets/id_agenix`.
   - `chmod` the key to 0500.
2. Use `ssh-keygen -t ed25519` to generate a temporary key.
   - Just keep pressing enter until the key is generated.
3. Add the key to the ssh-agent with `eval '$(ssh-agent -s)' && ssh-add ~/.ssh/id_ed25519`.
4. Add the temporary key to the GitHub.
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

1. Reset the VPS from the admin console that you got from the provider.
2. Get the public IPv4 address of the VPS.
3. Run `nix run github:nix-community/nixos-anywhere -- --flake .#<configuration name> --target-host root@<ip address>`
   - Change `<configuration name>` to the hostname of the machine you are deploying to.
   - Change `<ip address>` to the public IPv4 address of the VPS.
   - User need to have a nix environment to run this command.
   - Run the command under `/Users/spedon/.config/systems`.
4. Key in the password of the VPS if prompted.
5. You are good to go!
6. Remove the temporary key from the GitHub.

### NixOS (desktop)

1. Download the ISO from [NixOS download page](https://nixos.org/download).
2. Boot from the ISO.
3. Skip the graphical installer and open console.
4. Run `sudo su` to switch to root.
5. Repeat step 2 to 4 of [macOS](#macos).
6. Clone the repo with `git clone git@github.com:Sped0n/systems.git`.
   - Run the command under `/tmp`.
7. Find where the target configuration's `disko.nix` located.
8. Run `sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount <path to disko.nix>`
9. Move the repo to with `mv /tmp/systems /mnt/etc/nixos`.
10. Place the agenix identity key to `/mnt/etc/nixos/id_agenix`.
    - `chmod` the key to 0500.
11. Run `nixos-install --flake .#<configuration name>`.
    - Change `<configuration name>` to the hostname of the machine you are deploying to.
    - Run the command under `/mnt/etc/nixos`.
12. Reboot.
13. You are good to go!
14. Remove the temporary key from the GitHub.
