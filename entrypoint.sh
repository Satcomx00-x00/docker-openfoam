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
# Source the appropriate OpenFOAM environment script
source /usr/lib/openfoam/openfoam2306/etc/bashrc # Typical path for OpenFOAM 2306 from opencfd images

# Terminal header
print_header() {
    clear
    echo -e "\033[1;34m"
    echo "  ___                   _____  ___    _   __  ___ "
    echo " / _ \ _ __   ___ _ __ | ___|/ _ \  / \ |  \/  | "
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

# --- Variable Validation ---
print_message "Validating required environment variables..." $YELLOW
MISSING_VARS=0
if [ -z "$MPI" ]; then
    print_message "ERROR: Environment variable MPI is not set." $RED
    MISSING_VARS=1
fi
if [ -z "$MODE" ]; then
    print_message "ERROR: Environment variable MODE is not set." $RED
    MISSING_VARS=1
fi
# ARGUMENTS can potentially be empty, so we might not strictly require it to be non-empty.
# If it's essential, uncomment the check below.
# if [ -z "$ARGUMENTS" ]; then
#     print_message "ERROR: Environment variable ARGUMENTS is not set." $RED
#     MISSING_VARS=1
# fi
if [ -z "$ZIP_ARCHIVE_INPUT" ]; then
    print_message "ERROR: Environment variable ZIP_ARCHIVE_INPUT is not set." $RED
    MISSING_VARS=1
fi

if [ $MISSING_VARS -ne 0 ]; then
    print_message "One or more required environment variables are missing. Please configure them (e.g., via Portainer template). Exiting." $RED
    exit 1
else
    print_message "All required environment variables are present." $GREEN
fi
# --- End Variable Validation ---

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

print_message "Proceeding to run $MODE with $MPI MPI processes..." $GREEN
# Display a summary table
header="Simulation Summary"
# Make sure ZIP_OUTPUT_FOLDER is defined before displaying it
ZIP_OUTPUT_FOLDER="$ZIP_BASE-output.zip"
rows=("Input Archive: $ZIP_ARCHIVE_INPUT" "Output Archive: $ZIP_OUTPUT_FOLDER" "MPI Processes: $MPI" "Mode: $MODE" "Arguments: $ARGUMENTS")
display_table "$header" "${rows[@]}"

# Run mpirun (rely on ENV PATH set in Dockerfile)
mpirun -np $MPI $MODE $ARGUMENTS
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
