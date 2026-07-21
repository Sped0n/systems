FROM nixos/nix:2.35.1

LABEL org.opencontainers.image.source=https://github.com/Sped0n/systems

COPY nix.conf /etc/nix/nix.conf

ARG NIXPKGS_REV
RUN test -n "${NIXPKGS_REV:-}" \
 && nix profile add --profile /nix/var/nix/profiles/builder \
    "github:NixOS/nixpkgs/${NIXPKGS_REV}#fex-headless" \
    "github:NixOS/nixpkgs/${NIXPKGS_REV}#gnused" \
    "github:NixOS/nixpkgs/${NIXPKGS_REV}#openssh" \
    "github:NixOS/nixpkgs/${NIXPKGS_REV}#util-linuxMinimal" \
    --option sandbox false --option filter-syscalls false

ENV PATH="/nix/var/nix/profiles/builder/bin:${PATH}"

RUN mkdir -p /etc/ssh && cat > /etc/ssh/sshd_config <<'EOF'
Port 22
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
EOF

RUN ssh-keygen -A \
 && mkdir -p /root/.ssh \
 && chmod 700 /root/.ssh
COPY --chmod=600 darwin-builder_ed25519.pub /root/.ssh/authorized_keys

RUN sed -i 's/^root:!:/root:*:/' /etc/shadow

RUN echo 'source /nix/var/nix/profiles/default/etc/profile.d/nix.sh' >> /root/.bashrc \
 && echo 'export PATH=/nix/var/nix/profiles/builder/bin:$PATH' >> /root/.bashrc \
 && echo 'source /nix/var/nix/profiles/default/etc/profile.d/nix.sh' >> /root/.profile \
 && echo 'export PATH=/nix/var/nix/profiles/builder/bin:$PATH' >> /root/.profile \
 && echo '. /nix/var/nix/profiles/default/etc/profile.d/nix.sh' >> /etc/profile \
 && echo 'export PATH=/nix/var/nix/profiles/builder/bin:$PATH' >> /etc/profile

RUN echo 'sshd:x:74:74:sshd privsep:/var/empty:/bin/false' >> /etc/passwd \
 && echo 'sshd:x:74:' >> /etc/group \
 && mkdir -p /var/empty

EXPOSE 22
VOLUME /nix/store

COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
