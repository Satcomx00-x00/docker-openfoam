# Build this image after building the base image:
# docker build -t satcomx00/openfoam-base:latest -f Dockerfile.openfoam .
# docker build -t satcomx00/openfoam-runner:latest .

# Use the pre-built OpenFOAM base image
FROM satcomx00/openfoam-base:latest AS base

# Runtime specific environment variables
ENV OMPI_ALLOW_RUN_AS_ROOT=1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
# Ensure WM_PROJECT_DIR is set for the entrypoint script sourcing
ENV WM_PROJECT_DIR=/usr/lib/openfoam

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
