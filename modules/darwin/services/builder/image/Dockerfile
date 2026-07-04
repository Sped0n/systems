FROM nixos/nix:2.34.7

LABEL org.opencontainers.image.source=https://github.com/Sped0n/systems

RUN nix-env -iA nixpkgs.openssh nixpkgs.gnused \
    --option sandbox false --option filter-syscalls false

RUN cat > /etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
max-jobs = auto
cores = 0
sandbox = false
filter-syscalls = false
trusted-users = root
EOF

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
 && echo 'source /nix/var/nix/profiles/default/etc/profile.d/nix.sh' >> /root/.profile \
 && echo '. /nix/var/nix/profiles/default/etc/profile.d/nix.sh' >> /etc/profile

RUN echo 'sshd:x:74:74:sshd privsep:/var/empty:/bin/false' >> /etc/passwd \
 && echo 'sshd:x:74:' >> /etc/group \
 && mkdir -p /var/empty

EXPOSE 22
VOLUME /nix/store

COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
