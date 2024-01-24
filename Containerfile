ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-silverblue}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR:-main}"
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-${BASE_IMAGE_NAME}${IMAGE_FLAVOR}}"
ARG BASE_IMAGE="ghcr.io/ublue-os/${SOURCE_IMAGE}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-39}"

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS asus

ARG IMAGE_NAME="${IMAGE_NAME}"
ARG IMAGE_VENDOR="ublue-os"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-39}"

# Copy shared files between all images.
COPY system_files/shared /

# Install Asus kernel
RUN wget https://copr.fedorainfracloud.org/coprs/lukenukem/asus-linux/repo/fedora-$(rpm -E %fedora)/lukenukem-asus-linux-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/_copr_lukenukem-asus-linux.repo && \
    wget https://copr.fedorainfracloud.org/coprs/lukenukem/asus-kernel/repo/fedora-$(rpm -E %fedora)/lukenukem-asus-kernel-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/_copr_lukenukem-asus-kernel.repo && \
    rpm-ostree cliwrap install-to-root / && \
    rpm-ostree override replace \
    --experimental \
    --from repo=copr:copr.fedorainfracloud.org:lukenukem:asus-kernel \
        kernel \
        kernel-core \
        kernel-modules \
        kernel-modules-core \
        kernel-modules-extra && \
    git clone https://gitlab.com/asus-linux/firmware.git --depth 1 /tmp/asus-firmware && \
    cp -rf /tmp/asus-firmware/* /usr/lib/firmware/ && \
    rm -rf /tmp/asus-firmware

# Install akmods
COPY --from=ghcr.io/ublue-os/akmods:asus-${FEDORA_MAJOR_VERSION} /rpms /tmp/akmods-rpms

# Only run if FEDORA_MAJOR_VERSION is not 39
RUN if [ ${FEDORA_MAJOR_VERSION} -lt 39 ]; then \
    for REPO in $(rpm -ql ublue-os-akmods-addons|grep ^"/etc"|grep repo$); do \
        echo "akmods: enable default entry: ${REPO}" && \
        sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' ${REPO} \
    ; done && \
    wget https://negativo17.org/repos/fedora-multimedia.repo -O /etc/yum.repos.d/negativo17-fedora-multimedia.repo && \
    rpm-ostree install \
        kernel-tools \
        /tmp/akmods-rpms/kmods/*xpadneo*.rpm \
        /tmp/akmods-rpms/kmods/*xone*.rpm \
        /tmp/akmods-rpms/kmods/*openrazer*.rpm \
        /tmp/akmods-rpms/kmods/*v4l2loopback*.rpm \
        /tmp/akmods-rpms/kmods/*wl*.rpm && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo && \
    for REPO in $(rpm -ql ublue-os-akmods-addons|grep ^"/etc"|grep repo$); do \
        echo "akmods: disable default entry: ${REPO}" && \
        sed -i '1,/enabled=1/{s/enabled=1/enabled=0/}' ${REPO} \
    ; done \
; fi

# Setup things which are the same for every image
RUN /tmp/image-info.sh && \
    /tmp/asus-install.sh && \
    rm -rf /tmp/* /var/* && \    
    ostree container commit && \
    mkdir -p /var/tmp && chmod -R 1777 /tmp /var/tmp
