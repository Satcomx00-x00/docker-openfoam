FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
ENV wkdir=/usr/lib/
WORKDIR $wkdir
COPY . .

RUN rm /bin/sh && \
    ln -s /bin/bash /bin/sh

# setup timezone
ENV TZ=Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update  && \
    apt-get install -y software-properties-common  && \
    apt-add-repository ppa:apt-fast/stable -y  && \
    apt-get update  && \
    apt-get -y install apt-fast


# install essentials
RUN apt-fast update && \
    apt-fast install -y curl nano git htop build-essential software-properties-common zip

# install useful openfoam tools
RUN apt-fast install -y ffmpeg

RUN apt-fast upgrade -y
# download openfoam and update repos
# RUN curl https://dl.openfoam.com/add-debian-repo.sh | bash
# RUN apt-get update

# install latest openfoam
# RUN apt-get install -y openfoam-default

# add user "foam"
RUN useradd --user-group --create-home --shell /bin/bash foam ;\
    echo "foam ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Clone ThirdParty-common and openfoam repositories
RUN git clone https://develop.openfoam.com/Development/ThirdParty-common && \
    git clone https://develop.openfoam.com/Development/openfoam -j 8

# Source bashrc and build OpenFOAM
# RUN /bin/bash -c "source /root/.bashrc"
# RUN source $wkdir/openfoam/etc/bashrc
ENV WM_PROJECT_DIR=$wkdir/openfoam

RUN chmod +x $wkdir/openfoam/Allwmake

RUN source $wkdir/openfoam/etc/bashrc && cd openfoam/ && ./Allwmake -j 32 -s -q -l

# export LD_LIBRARY_PATH for foam user
RUN echo 'export LD_LIBRARY_PATH=$wkdir/ThirdParty-common/platforms/linux64Gcc/fftw-3.3.10/lib:$LD_LIBRARY_PATH' >> /home/foam/.bashrc

# source openfoam and fix docker mpi for foam user
RUN echo 'source /usr/lib/openfoam/openfoam/etc/bashrc' >> /home/foam/.bashrc ;\
    echo 'export OMPI_MCA_btl_vader_single_copy_mechanism=none' >> /home/foam/.bashrc

# Change environmental variables for foam user
# RUN sed -i '/export WM_PROJECT_USER_DIR=/cexport WM_PROJECT_USER_DIR="/data/foam-$WM_PROJECT_VERSION"' /usr/lib/openfoam/openfoam/etc/bashrc

USER foam
RUN source $wkdir/openfoam/etc/bashrc && \
    foamSystemCheck && \
    foamInstallationTest && \
    foam


ENTRYPOINT [ "./entrypoint.sh" ]
