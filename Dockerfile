# Use UBI minimal as base for better OpenShift compatibility
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

# Adding labels for OpenShift
LABEL io.k8s.description="SSH Server for OpenShift" \
      io.k8s.display-name="SSH Server" \
      io.openshift.expose-services="2222:ssh" \
      io.openshift.tags="ssh,sshd" \
      io.openshift.non-scalable="true"

# Install OpenSSH Server and set up the environment in a single layer
# OpenShift runs containers with arbitrary user IDs, so we make everything accessible
RUN microdnf -y update && \
    microdnf -y install openssh-server shadow-utils bash rsync && \
    microdnf clean all && \
    # Create directories with correct permissions for OpenShift
    mkdir -p /var/run/sshd /etc/ssh/authorized_keys /var/lib/sshd && \
    chmod -R 0775 /var/run/sshd /etc/ssh/authorized_keys /var/lib/sshd && \
    # Create the admin user with specific UID/GID
    groupadd -g 1001 sshd-group && \
    useradd -u 1001 -g 1001 -m -s /bin/bash -d /var/lib/sshd sshd-user && \
    echo "sshd-user:password123" | chpasswd && \
    mkdir -p /etc/ssh/authorized_keys/sshd-user && \
    touch /etc/ssh/authorized_keys/sshd-user && \
    chmod -R 0775 /etc/ssh/authorized_keys/sshd-user && \
    chown -R 1001:1001 /var/lib/sshd && \
    # Modify sshd_config to work with OpenShift
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/authorized_keys/%u" >> /etc/ssh/sshd_config && \
    echo "Port 2222" >> /etc/ssh/sshd_config && \
    echo "StrictModes no" >> /etc/ssh/sshd_config && \
    echo "PidFile /var/lib/sshd/sshd.pid" >> /etc/ssh/sshd_config && \
    # Generate host keys during build to avoid permission issues at runtime
    ssh-keygen -A && \
    # Set sshd to handle startup gracefully
    echo "#!/bin/bash" > /usr/local/bin/entrypoint.sh && \
    echo "set -e" >> /usr/local/bin/entrypoint.sh && \
    echo "# Fix permissions for OpenShift arbitrary UID" >> /usr/local/bin/entrypoint.sh && \
    echo "if [ ! -d /var/lib/sshd/.ssh ]; then" >> /usr/local/bin/entrypoint.sh && \
    echo "  mkdir -p /var/lib/sshd/.ssh" >> /usr/local/bin/entrypoint.sh && \
    echo "  chmod 700 /var/lib/sshd/.ssh" >> /usr/local/bin/entrypoint.sh && \
    echo "fi" >> /usr/local/bin/entrypoint.sh && \
    echo "# Copy SSH host keys from cache if needed" >> /usr/local/bin/entrypoint.sh && \
    echo "if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then" >> /usr/local/bin/entrypoint.sh && \
    echo "  cp -rf /etc/ssh.cache/* /etc/ssh/" >> /usr/local/bin/entrypoint.sh && \
    echo "fi" >> /usr/local/bin/entrypoint.sh && \
    echo "chmod -R 0775 /etc/ssh /var/run/sshd /etc/ssh/authorized_keys" >> /usr/local/bin/entrypoint.sh && \
    echo "echo 'Starting SSH server on port 2222'" >> /usr/local/bin/entrypoint.sh && \
    echo "exec \"\$@\"" >> /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh && \
    # Create SSH key cache to avoid issues with read-only filesystems
    cp -a /etc/ssh /etc/ssh.cache

# OpenSSH server listens on port 2222 (OpenShift often restricts port 22)
EXPOSE 2222

# Set working directory to a writable location
WORKDIR /var/lib/sshd

# Set permissions for OpenShift arbitrary UID support
RUN chmod -R 0775 /etc/ssh /var/run/sshd /etc/ssh.cache /usr/local/bin/entrypoint.sh && \
    mkdir -p /var/lib/sshd/.ssh && \
    chmod 700 /var/lib/sshd/.ssh && \
    chown -R 1001:1001 /var/lib/sshd

# Run container as non-root user
USER 1001

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/etc/ssh/sshd_config"] 