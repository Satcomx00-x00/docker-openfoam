# Build this image using the official OpenFOAM base image:
# docker build -t satcomx00/openfoam-runner:latest .

# Use the OpenCFD development image for OpenFOAM 2306
FROM opencfd/openfoam-dev:2306 AS base

# Install runtime dependencies needed by the entrypoint script (zip/unzip might already be present, but ensure they are)
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Runtime specific environment variables
ENV OMPI_ALLOW_RUN_AS_ROOT=1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
# Ensure it's executable
RUN chmod +x /entrypoint.sh

# Set the final working directory for the container runtime
WORKDIR /workdir

# Define the entrypoint for the container
# Source the OpenFOAM environment setup script and then execute the custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Optional: Default command if entrypoint needs arguments or for debugging
CMD ["bash"]
