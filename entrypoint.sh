#!/bin/bash
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

print_message "Unzipping $ZIP_ARCHIVE_INTPUT ..." $GREEN
unzip $ZIP_ARCHIVE_INTPUT

# Source OpenFOAM bashrc
print_message "Sourcing OpenFOAM bashrc..." $GREEN
source /usr/lib/openfoam/etc/bashrc


# Check if OpenFOAM environment is sourced successfully
if [ -z "$WM_PROJECT_DIR" ]; then
    print_message "Failed to source OpenFOAM bashrc. Exiting." $RED
    exit 1
fi

# Set working directory
WORKDIR="/workdir/$DIRECTORY"
cd "$WORKDIR" || exit

# Set ulimit
ulimit -s unlimited
ulimit -v unlimited

# Run blockMesh
print_message "Running blockMesh..." $GREEN
blockMesh


FOAM_DIR_PATH="$WM_PROJECT_DIR"
print_message "Running $MODE with $MPI MPI processes..." $GREEN

mpirun -n $MPI $MODE $ARGUMENTS

# Check for errors
if [ $? -eq 0 ]; then
    print_message "$MODE completed successfully." $GREEN
else
    print_message "$MODE encountered an error. Please check." $RED
fi

ZIP_OUTPUT_FOLDER = $ZIP_ARCHIVE_INTPUT-output.zip

# Zip output folder
print_message "Zipping $ZIP_ARCHIVE_INTPUT to $ZIP_OUTPUT_FOLDER ..." $GREEN
zip -r "$ZIP_OUTPUT_FOLDER" "$ZIP_ARCHIVE_INTPUT" || { print_message "Failed to zip $ZIP_ARCHIVE_INTPUT. Exiting." $RED; exit 1; }
print_message "Successfully zipped $OUTPUT_FOLDER to $ZIP_OUTPUT_FOLDER." $GREEN