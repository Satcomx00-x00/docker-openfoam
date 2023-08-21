FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Set the shell to bash
SHELL ["/bin/bash", "-c"]

# setup timezone
ENV TZ=Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# install essentials
RUN apt-get update 

# install RUN apt-get install -y ssh
RUN apt-get update && \
    apt-get install -y curl nano git htop build-essential software-properties-common zip

		
# install useful openfoam tools
RUN apt-get install -y ffmpeg

# download openfoam and update repos
# RUN curl https://dl.openfoam.com/add-debian-repo.sh | bash
# RUN apt-get update

# install latest openfoam
# RUN apt-get install -y openfoam-default

RUN git clone https://develop.openfoam.com/Development/ThirdParty-common
RUN git clone https://develop.openfoam.com/Development/openfoam
RUN cd openfoam

RUN source etc/bashrc
RUN 
RUN ./Allwmake -j 32 -s -q -l

# add user "foam"
RUN useradd --user-group --create-home --shell /bin/bash foam ;\
	echo "foam ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    
RUN export LD_LIBRARY=/home/foam/ThirdParty-common/platforms/linux64Gcc/fftw-3.3.10/lib:$LD_LIBRARY_PATH

# source openfoam and fix docker mpi
RUN echo "source /usr/lib/openfoam/openfoam/etc/bashrc" >> ~foam/.bashrc ;\
   echo "export OMPI_MCA_btl_vader_single_copy_mechanism=none" >> ~foam/.bashrc

# change environmental variables to make sure $WM_PROJECT_USER_DIR is outside of the container
RUN sed -i '/export WM_PROJECT_USER_DIR=/cexport WM_PROJECT_USER_DIR="/data/foam-$WM_PROJECT_VERSION"' /usr/lib/openfoam/openfoam/etc/bashrc

# change user to "foam"
USER foam

RUN foamInstallationTest

ENTRYPOINT [ "./entrypoint.sh" ]
