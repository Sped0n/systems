# Provisioning

Private flake inputs require repository access. Secret decryption requires the
configured age identities on the target.

| Target                             | Status   | Guide                                         |
| ---------------------------------- | -------- | --------------------------------------------- |
| Linux with standalone Home Manager | Current  | [Linux Home Manager](./linux-home-manager.md) |
| macOS                              | Current  | [macOS](./macos.md)                           |
| NixOS servers                      | Current  | [NixOS server](./nixos-server.md)             |
| NixOS desktop                      | Archived | [NixOS desktop](./nixos-desktop.md)           |

## Secrets and age identities

The configuration uses SSH Ed25519 private keys as age identities. Existing keys
can be reused. Unattended activation requires decryption without an interactive
passphrase prompt.

### Key paths

| Configuration        | Private key path                | Definition                                               |
| -------------------- | ------------------------------- | -------------------------------------------------------- |
| NixOS and nix-darwin | `/etc/ssh/ssh_host_ed25519_key` | [`modules/shared/age.nix`](../../modules/shared/age.nix) |
| Home Manager         | `/etc/ssh/ssh_user_ed25519_key` | [`hm/shared/age.nix`](../../hm/shared/age.nix)           |

Home Manager does not read `~/.ssh/id_ed25519` by default. The user normally
cannot read the host private key. Other paths require a change to
`age.identityPaths`.

### Key setup

- Preserve existing host keys. `sudo ssh-keygen -A` generates missing host keys
  without replacing existing ones.
- Reuse a user key or generate one at an unused path with
  `ssh-keygen -t ed25519 -f ~/.ssh/agenix_ed25519`. Do not overwrite an existing key.
- On NixOS and nix-darwin, store the user private key in the private secrets
  repository as `ages/<hostname>-user.age`, encrypted to the host key. System
  activation decrypts it to `/etc/ssh/ssh_user_ed25519_key`, owned by
  `vars.username` with mode `0400`.
- For standalone Home Manager, install the user private key at
  `/etc/ssh/ssh_user_ed25519_key` before the first activation. Set its owner to
  the Home Manager user and its mode to `0400`. Check any existing file before
  replacing it. Home Manager does not create this identity file.

Plaintext private keys must stay out of both repositories and the Nix store.
Store user private keys in the private secrets repository only as encrypted
`.age` files.

### Recipients and rekeying

Add the selected public keys as recipients for the required secrets in the
private secrets repository. From that repository, rekey with an identity that
can already decrypt the affected secrets:

```bash
agenix -i /path/to/already-authorized-private-key -r
```

Use sudo for a root-owned host identity. New recipients cannot decrypt existing
ciphertext until rekeying completes. Commit the encrypted changes and update the
systems flake's secrets input before activation.

## Temporary repository access

An existing authorized SSH key can provide repository access. If a temporary key
is needed, create it at an unused path:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/provisioning_ed25519

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/provisioning_ed25519
```

Add only its public key to GitHub. Remove the temporary GitHub credential after
provisioning. Do not revoke a reused key that is still needed. The temporary key
is separate from the persistent user age identity.

## Troubleshooting

[Troubleshooting](troubleshooting.md) covers host inspection, hardware
configuration capture, and low-memory installation.
