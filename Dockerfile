# Use the official Ubuntu image as the base
FROM ubuntu:22.04

# Set non-interactive mode for installations
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory variables
ENV wkdir=/usr/lib
ENV WM_THIRD_PARTY_DIR=/usr/lib/ThirdParty-common/
WORKDIR $wkdir

# Copy the entire context into the container
COPY . .
COPY --chmod=777 entrypoint.sh entrypoint.sh
RUN chmod +x ./entrypoint.sh

# Update and install apt-fast
RUN rm /bin/sh && \
    ln -s /bin/bash /bin/sh && \
    apt-get update && \
    apt-get install -y software-properties-common && \
    apt-add-repository ppa:apt-fast/stable -y && \
    apt-get update && \
    apt-get -y install apt-fast

# Install essential packages
RUN apt-fast update && \
    apt-fast install -y curl nano git htop build-essential software-properties-common zip libopenmpi-dev script

# Install additional tools
RUN apt-fast install -y ffmpeg flex

# Perform system upgrade
RUN apt-fast upgrade -y

# Add user "foam"
RUN useradd --user-group --create-home --shell /bin/bash foam && \
    echo "foam ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers


# Clone ThirdParty-common and OpenFOAM repositories
RUN git clone https://develop.openfoam.com/Development/ThirdParty-common && \
    git clone https://develop.openfoam.com/Development/openfoam -j 8

# Set environment variables and build OpenFOAM
ENV WM_PROJECT_DIR=$wkdir/openfoam
RUN chmod +x $wkdir/openfoam/Allwmake && \
    chmod +x entrypoint.sh && \
    source $wkdir/openfoam/etc/bashrc && \
    cd openfoam/ && \
    ./Allwmake -j 64 -s -q -l

# Configure environment for foam user
RUN echo 'export LD_LIBRARY_PATH=$wkdir/ThirdParty-common/platforms/linux64Gcc/fftw-3.3.10/lib:$LD_LIBRARY_PATH' >> /home/foam/.bashrc && \
    echo 'source /usr/lib/openfoam/etc/bashrc' >> /home/foam/.bashrc && \
    echo 'export OMPI_MCA_btl_vader_single_copy_mechanism=none' >> /home/foam/.bashrc

# RUN chmod +xrw -R /workdir



# Switch to the foam user
# USER foam

# Test OpenFOAM installation
RUN source $wkdir/openfoam/etc/bashrc && \
    foamSystemCheck && \
    foamInstallationTest


# Set the entrypoint
ENTRYPOINT [ "./entrypoint.sh" ]
