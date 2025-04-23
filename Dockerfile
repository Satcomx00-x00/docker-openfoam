FROM ubuntu:jammy

ENV DEBIAN_FRONTEND=noninteractive
ENV wkdir=/usr/lib
ENV WM_THIRD_PARTY_DIR=/usr/lib/ThirdParty-common/
ENV WM_PROJECT_DIR=/usr/lib/openfoam
ENV OMPI_ALLOW_RUN_AS_ROOT=1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

WORKDIR $wkdir

# Copy entrypoint.sh first to make sure it exists
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Install dependencies and useful packages
RUN apt-get update && apt-get install -y \
    build-essential curl git \
    libopenmpi-dev flex \
    software-properties-common \
    zip unzip wget vim nano htop \
    tar gzip bzip2 xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://develop.openfoam.com/Development/ThirdParty-common \
    && git clone https://develop.openfoam.com/Development/openfoam -j 8

# Build OpenFOAM using bash
SHELL ["/bin/bash", "-c"]
RUN cd openfoam \
    && chmod +x ./Allwmake \
    && source ./etc/bashrc \
    && ./Allwmake -j $(nproc) -s -q -l \
    && echo 'source /usr/lib/openfoam/etc/bashrc' >> /root/.bashrc

# Add foam user
RUN useradd -m -s /bin/bash foam && \
    echo 'source /usr/lib/openfoam/etc/bashrc' >> /home/foam/.bashrc && \
    echo 'export OMPI_MCA_btl_vader_single_copy_mechanism=none' >> /home/foam/.bashrc

# Test installation
RUN source /usr/lib/openfoam/etc/bashrc && \
    foamSystemCheck && \
    foamInstallationTest

WORKDIR /
ENTRYPOINT ["/entrypoint.sh"]
#CMD ["bash"]
