#!/bin/bash
#==============================================================================
# OpenFOAM Docker Runner
# Version: 1.0.0
# Date: $(date "+%Y-%m-%d")
# Repository: github.com/openfoam/docker-runner
#==============================================================================
# MPI = 4
# MODE = interFoam
# ARGUMENTS = -parallel
source /opt/openfoam11/etc/bashrc
# Terminal header
print_header() {
    clear
    echo -e "\033[1;34m"
    echo "  ___                   _____  ___    _   __  ___ "
    echo " / _ \ _ __   ___ _ __ |  ___|/ _ \  / \ |  \/  | "
    echo "| | | | '_ \ / _ \ '_ \| |_  | | | |/ _ \| |\/| | "
    echo "| |_| | |_) |  __/ | | |  _| | |_| / ___ \ |  | | "
    echo " \___/| .__/ \___|_| |_|_|    \___/_/   \_\_|  |_| "
    echo "      |_|                                         "
    echo -e "\033[0m"
    echo -e "\033[1;32m===== OpenFOAM Docker Runner v1.0.0 =====\033[0m"
    echo -e "\033[0;36mStarting simulation environment...\033[0m"
    echo ""
}

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

# Print header
print_header

cd /workdir
mkdir -p OpenFoam
cd OpenFoam
# script terminal.log
print_message "Unzipping $ZIP_ARCHIVE_INPUT ..." $GREEN
# Extract the filename without .zip extension from the input path
ZIP_BASE=$(basename "$ZIP_ARCHIVE_INPUT" .zip)
# Unzip, ensuring it extracts into a directory named $ZIP_BASE if the archive root isn't already named that.
# A common pattern is that the zip file contains a single top-level directory.
unzip -o "/workdir/$ZIP_ARCHIVE_INPUT"
# Find the actual directory name created by unzip (might differ slightly if zip contains a root folder)
# Assuming the zip extracts a single directory, find it. Handle potential spaces.
EXTRACTED_DIR=$(ls -d */ | head -n 1 | sed 's/\///')
if [ -z "$EXTRACTED_DIR" ]; then
    print_message "Could not determine the extracted directory name. Exiting." $RED
    exit 1
fi
# Use the actual extracted directory name, might be different from ZIP_BASE
WORKDIR_CASE="/workdir/OpenFoam/$EXTRACTED_DIR"
print_message "Changing working directory to $WORKDIR_CASE" $GREEN
cd "$WORKDIR_CASE"
CD_EXIT_CODE=$?
if [ $CD_EXIT_CODE -ne 0 ]; then
    print_message "Failed to change directory to $WORKDIR_CASE (Exit Code: $CD_EXIT_CODE). Exiting." $RED
    exit 1
fi

# Environment variables (PATH, LD_LIBRARY_PATH, WM_PROJECT_DIR etc.)
# are expected to be set by the Dockerfile ENV instructions when using the official base image.

# Set ulimit
ulimit -s unlimited
ulimit -v unlimited

# Debugging: Verify current directory and existence of system/blockMeshDict
print_message "Current directory before blockMesh: $(pwd)" $YELLOW
print_message "Listing contents of current directory:" $YELLOW
ls -la
print_message "Checking for system/blockMeshDict file:" $YELLOW
if [ -f "system/blockMeshDict" ]; then
    print_message "Found system/blockMeshDict." $GREEN
else
    print_message "ERROR: system/blockMeshDict not found in $(pwd)." $RED
    # Optionally list system directory if it exists, even if file doesn't
    if [ -d "system" ]; then
        print_message "Contents of system/ directory:" $YELLOW
        ls -la system/
    else
        print_message "ERROR: system/ directory not found in $(pwd)." $RED
    fi
    # Exit here if the file is mandatory for blockMesh
    # exit 1 # Consider exiting if file not found
fi

# Run blockMesh (rely on ENV PATH set in Dockerfile)
print_message "Running blockMesh..." $GREEN
blockMesh
BLOCKMESH_EXIT_CODE=$?

# Check if blockMesh succeeded
if [ $BLOCKMESH_EXIT_CODE -ne 0 ]; then
    print_message "blockMesh failed with exit code $BLOCKMESH_EXIT_CODE. Skipping simulation and zipping." $RED
    exit $BLOCKMESH_EXIT_CODE
fi

# If blockMesh succeeded, proceed with the simulation
print_message "Running $MODE with $MPI MPI processes..." $GREEN
# Display a summary table
header="Simulation Summary"
# Make sure ZIP_OUTPUT_FOLDER is defined before displaying it
ZIP_OUTPUT_FOLDER="$ZIP_BASE-output.zip"
rows=("Input Archive: $ZIP_ARCHIVE_INPUT" "Output Archive: $ZIP_OUTPUT_FOLDER" "MPI Processes: $MPI" "Mode: $MODE" "Arguments: $ARGUMENTS")
display_table "$header" "${rows[@]}"

# Run mpirun (rely on ENV PATH set in Dockerfile)
mpirun -n $MPI $MODE $ARGUMENTS
MPIRUN_EXIT_CODE=$?

# Check for mpirun errors
if [ $MPIRUN_EXIT_CODE -eq 0 ]; then
    print_message "$MODE completed successfully." $GREEN

    # Change back to the base workdir before zipping
    cd /workdir

    # Zip output folder relative to /workdir
    print_message "Zipping $EXTRACTED_DIR to $ZIP_OUTPUT_FOLDER ..." $GREEN
    zip -r "/workdir/$ZIP_OUTPUT_FOLDER" "OpenFoam/$EXTRACTED_DIR" || {
        print_message "Failed to zip OpenFoam/$EXTRACTED_DIR. Exiting." $RED
        exit 1 # Exit if zipping fails
    }
    print_message "Successfully zipped $ZIP_OUTPUT_FOLDER." $GREEN
    print_message "Work done, you can find your outputs to $ZIP_OUTPUT_FOLDER in your personal volume."
else
    print_message "$MODE encountered an error (Exit Code: $MPIRUN_EXIT_CODE). Please check the log. Output will not be zipped." $RED
    # Exit with the error code from mpirun
    exit $MPIRUN_EXIT_CODE
fi
