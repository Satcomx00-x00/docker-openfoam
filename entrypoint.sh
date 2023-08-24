#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${NC}"
}

# Source OpenFOAM bashrc
print_message "Sourcing OpenFOAM bashrc..." $GREEN
source /usr/lib/openfoam/etc/bashrc

# Check if OpenFOAM environment is sourced successfully
if [ -z "$WM_PROJECT_DIR" ]; then
    print_message "Failed to source OpenFOAM bashrc. Exiting." $RED
    exit 1
fi

# Set working directory
WORKDIR="/workdir"
cd "$WORKDIR" || exit

# Set ulimit
ulimit -s unlimited
ulimit -v unlimited

# Run blockMesh
print_message "Running blockMesh..." $GREEN
blockMesh

# Run simpleFoam
# MPI=4  # Number of MPI processes
FOAM_DIR_PATH="$WM_PROJECT_DIR"
print_message "Running simpleFoam with $MPI MPI processes..." $GREEN
mpirun -np "$MPI" simpleFoam

# Check for errors in simpleFoam
if [ $? -eq 0 ]; then
    print_message "simpleFoam completed successfully." $GREEN
else
    print_message "simpleFoam encountered an error. Please check." $RED
fi
