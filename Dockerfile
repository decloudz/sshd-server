FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

# Install OpenSSH Server
RUN microdnf -y update && \
    microdnf -y install openssh-server shadow-utils && \
    microdnf clean all

# Create necessary directories
RUN mkdir -p /var/run/sshd /etc/ssh/authorized_keys

# Create the admin user with specific UID/GID
RUN groupadd -g 1001200000 admin && \
    useradd -u 1001200000 -g 1001200000 -m -s /bin/bash admin && \
    echo "admin:password123" | chpasswd && \
    mkdir -p /etc/ssh/authorized_keys && \
    touch /etc/ssh/authorized_keys/admin && \
    chmod 600 /etc/ssh/authorized_keys/admin && \
    chown 1001200000:1001200000 /etc/ssh/authorized_keys/admin && \
    chown 1001200000:1001200000 /home/admin

# Set sshd to create keys on first start if they don't exist
RUN echo "#!/bin/sh" > /usr/local/bin/entrypoint.sh && \
    echo "if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then" >> /usr/local/bin/entrypoint.sh && \
    echo "  ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N \"\"" >> /usr/local/bin/entrypoint.sh && \
    echo "fi" >> /usr/local/bin/entrypoint.sh && \
    echo "if [ ! -f /etc/ssh/ssh_host_ecdsa_key ]; then" >> /usr/local/bin/entrypoint.sh && \
    echo "  ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N \"\"" >> /usr/local/bin/entrypoint.sh && \
    echo "fi" >> /usr/local/bin/entrypoint.sh && \
    echo "if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then" >> /usr/local/bin/entrypoint.sh && \
    echo "  ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N \"\"" >> /usr/local/bin/entrypoint.sh && \
    echo "fi" >> /usr/local/bin/entrypoint.sh && \
    echo "exec \$@" >> /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# Copy default sshd_config
COPY sshd_config /etc/ssh/sshd_config

# OpenSSH server listens on port 2222
EXPOSE 2222

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/etc/ssh/sshd_config"] 