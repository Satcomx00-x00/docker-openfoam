#!/bin/bash
# entrypoint.sh
# MPI = 4
# MODE = interFoam
# ARGUMENTS = -parallel
cd /workdir
chmod +xrw -R /workdir

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

# Function to display a shell table
display_table() {
    local header="$1"
    shift
    local rows=("$@")
    printf "%s\n" "$header"
    printf "%s\n" "${rows[@]}"
}

cd /workdir
mkdir -p OpenFoam
cd OpenFoam
print_message "Unzipping $ZIP_ARCHIVE_INPUT ..." $GREEN
unzip "/workdir/$ZIP_ARCHIVE_INPUT"

# Source OpenFOAM bashrc
print_message "Sourcing OpenFOAM bashrc..." $GREEN
source /usr/lib/openfoam/etc/bashrc

# Check if OpenFOAM environment is sourced successfully
if [ -z "$WM_PROJECT_DIR" ]; then
    print_message "Failed to source OpenFOAM bashrc. Exiting." $RED
    exit 1
fi

# Set working directory
WORKDIR="/workdir/$ZIP_ARCHIVE_INPUT"
cd "$WORKDIR" || exit

# Set ulimit
ulimit -s unlimited
ulimit -v unlimited

# Run blockMesh
print_message "Running blockMesh..." $GREEN
blockMesh

FOAM_DIR_PATH="$WM_PROJECT_DIR"
print_message "Running $MODE with $MPI MPI processes..." $GREEN


print_message "Parameters =>  $MPI $MODE $ARGUMENTS"

# Redirect mpirun output to a log file
mpirun -n $MPI $MODE $ARGUMENTS > terminal.log 2>&1

# Check for errors
if [ $? -eq 0 ]; then
    print_message "$MODE completed successfully." $GREEN
else
    print_message "$MODE encountered an error. Please check the log." $RED
fi

ZIP_OUTPUT_FOLDER="$ZIP_ARCHIVE_INPUT-output.zip"

# Zip output folder
print_message "Zipping $ZIP_ARCHIVE_INPUT to $ZIP_OUTPUT_FOLDER ..." $GREEN
zip -r "/workdir/$ZIP_OUTPUT_FOLDER" "/workdir$ZIP_ARCHIVE_INPUT-output" || {
    print_message "Failed to zip $ZIP_ARCHIVE_INPUT. Exiting." $RED
    exit 1
}
print_message "Successfully zipped $ZIP_OUTPUT_FOLDER." $GREEN

# Display a summary table
header="Simulation Summary"
rows=("Input Archive: $ZIP_ARCHIVE_INPUT" "Output Archive: $ZIP_OUTPUT_FOLDER" "MPI Processes: $MPI" "Mode: $MODE" "Arguments: $ARGUMENTS")
display_table "$header" "${rows[@]}"
