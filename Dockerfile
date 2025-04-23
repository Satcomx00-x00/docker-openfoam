# Build this image using the official OpenFOAM base image:
# docker build -t satcomx00/openfoam-runner:latest .

# Use the official OpenFOAM base image with ParaView 
# openfoam/openfoam11-paraview510
# satcomx00/openfoam-base:latest
FROM openfoam/openfoam11-paraview510 AS base

# Install runtime dependencies needed by the entrypoint script (zip/unzip might already be present, but ensure they are)
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Runtime specific environment variables
ENV OMPI_ALLOW_RUN_AS_ROOT=1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
# Set WM_PROJECT_DIR to the typical path in the official image
ENV WM_PROJECT_DIR=/opt/openfoam-dev/
# Explicitly add required OpenFOAM binary directories to the PATH
ENV PATH=/opt/openfoam-dev/platforms/linux64GccDPInt32Opt/bin:/opt/openfoam-dev/bin:${PATH}

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
# Ensure it's executable
RUN chmod +x /entrypoint.sh

# Set the final working directory for the container runtime
WORKDIR /workdir

# Define the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Optional: Default command if entrypoint needs arguments or for debugging
# CMD ["bash"]
