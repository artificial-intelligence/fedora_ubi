# There's no @sha256 for Renovate to trigger rebuild whenever the parent
# digest changes because we don't use anything from the parent image.
FROM fedora:latest AS builder

ARG FEDORA_VERSION=41

RUN mkdir -p /mnt/rootfs

# Install fedora-release and import the GPG key. We can then later install more packages and verify the signatures
RUN \
    dnf install --installroot /mnt/rootfs \
        fedora-release \
        --releasever ${FEDORA_VERSION} --setopt install_weak_deps=false --nodocs --nogpgcheck -y && \
    rpm --root=/mnt/rootfs --import /mnt/rootfs/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${FEDORA_VERSION}-primary

RUN \
    dnf install --installroot /mnt/rootfs --setopt=reposdir=/etc/yum.repos.d/ \
        bash \
        coreutils-single \
        crypto-policies-scripts \
        curl-minimal \
        findutils \
        gdb-gdbserver \
        glibc-minimal-langpack \
        gzip \
        langpacks-en \
        libcurl-minimal \
        rootfiles \
        tar \
        vim-minimal \
        yum \
        --releasever ${FEDORA_VERSION} --setopt install_weak_deps=false --nodocs -y && \
    dnf --installroot /mnt/rootfs -y remove policycoreutils diffutils libselinux-utils && \
    dnf --installroot /mnt/rootfs clean all

RUN rm -rf /mnt/rootfs/var/cache/* /mnt/rootfs/var/log/dnf* /mnt/rootfs/var/log/yum.* /mnt/rootfs/var/lib/dnf/*

# Set install langs macro so that new rpms that get installed will
# only install langs that we limit it to.
RUN echo "%_install_langs C.utf8" > /mnt/rootfs/etc/rpm/macros.image-language-conf && \
    echo "LANG=C.utf8" > /mnt/rootfs/etc/locale.conf

# Remove machine-id on pre generated images
RUN rm -f /mnt/rootfs/etc/machine-id && touch /mnt/rootfs/etc/machine-id && chmod 0444 /mnt/rootfs/etc/machine-id

# Manually mask off the systemd units and service so we don't get a login prompt
RUN cd /mnt/rootfs/etc/systemd/system/ && ln -s /dev/null systemd-logind.service && \
    ln -s /dev/null getty.target && ln -s /dev/null console-getty.service && \
    ln -s /dev/null sys-fs-fuse-connections.mount && ln -s /dev/null systemd-remount-fs.service && \
    ln -s /dev/null dev-hugepages.mount

# Create the /run/lock file
RUN install -d /mnt/rootfs/run/lock -m 0755 -o root -g root

FROM scratch

#labels for container catalog
LABEL summary="Provides the latest release of Fedora."
LABEL description="The Fedora Base Image"
LABEL io.k8s.description="The Fedora Base Image"
LABEL io.k8s.display-name="Fedora Base Image"
LABEL io.openshift.expose-services=""
LABEL io.openshift.tags="base fedora"

ENV container oci

COPY --from=builder /mnt/rootfs/ /

CMD ["/bin/bash"]
