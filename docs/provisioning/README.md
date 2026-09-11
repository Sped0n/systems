# Provisioning

Choose the guide for the target being provisioned. These procedures assume the
repository's private flake inputs and age identities are available where the
flake is evaluated.

| Target                             | Status   | Guide                                         |
| ---------------------------------- | -------- | --------------------------------------------- |
| Linux with standalone Home Manager | Current  | [Linux Home Manager](./linux-home-manager.md) |
| macOS                              | Current  | [macOS](./macos.md)                           |
| NixOS servers                      | Current  | [NixOS server](./nixos-server.md)             |
| NixOS desktop                      | Archived | [NixOS desktop](./nixos-desktop.md)           |

## Helpers

[`inspect-host.sh`](inspect-host.sh) captures read-only host facts.
[`ubuntu-workstation.sh`](ubuntu-workstation.sh) checks and, after explicit
confirmation, applies Ubuntu-owned prerequisites for the standalone Home
Manager workstation.

## Secrets and age identities

The user's age key is used by Home Manager because the user normally cannot read
the machine SSH private key. Secrets may also be encrypted to the machine key.

1. Generate the user key with `ssh-keygen -t ed25519` if it does not exist.
2. Add the user and machine public keys to the private secrets repository.
3. Rekey the secrets after adding recipients:

   ```bash
   sudo agenix -i /etc/ssh/ssh_host_ed25519_key -r
   ```

Generate missing machine SSH host keys with `sudo ssh-keygen -A`. Never copy a
private host key into the systems repository.

## Temporary repository access

Fresh installations may need a temporary SSH key to clone private repositories:

```bash
ssh-keygen -t ed25519

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Add only the public key to GitHub, and remove that credential after provisioning.
This bootstrap key is separate from the persistent user age identity.

## Troubleshooting

See [Troubleshooting](troubleshooting.md) for host inspection, hardware
configuration capture, and low-memory installation guidance.
