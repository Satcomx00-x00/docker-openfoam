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

# Get the list of directories before extraction
DIRS_BEFORE=$(ls -d */ 2>/dev/null | sort)

# Unzip and capture the extraction info
unzip -q -o "/workdir/$ZIP_ARCHIVE_INPUT"
UNZIP_EXIT_CODE=$?
if [ $UNZIP_EXIT_CODE -ne 0 ]; then
    print_message "Failed to unzip $ZIP_ARCHIVE_INPUT (Exit Code: $UNZIP_EXIT_CODE). Exiting." $RED
    exit $UNZIP_EXIT_CODE
fi

# Get the list of directories after extraction
DIRS_AFTER=$(ls -d */ 2>/dev/null | sort)

# Find the new directory created by extraction
EXTRACTED_DIR=$(comm -13 <(echo "$DIRS_BEFORE") <(echo "$DIRS_AFTER") | head -n 1 | sed 's/\///')

# Fallback: if no new directory detected, try alternative method
if [ -z "$EXTRACTED_DIR" ]; then
    # Try to extract directory name from unzip output
    EXTRACTED_DIR=$(unzip -l "/workdir/$ZIP_ARCHIVE_INPUT" | grep -E "/$" | head -n 1 | awk '{print $4}' | sed 's/\///')
fi

# Final fallback: use the first directory found
if [ -z "$EXTRACTED_DIR" ]; then
    EXTRACTED_DIR=$(ls -d */ 2>/dev/null | head -n 1 | sed 's/\///')
fi

if [ -z "$EXTRACTED_DIR" ]; then
    print_message "Could not determine the extracted directory name. Exiting." $RED
    exit 1
fi

print_message "Detected extracted directory: $EXTRACTED_DIR" $GREEN
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

# --- Debugging: Check parallel decomposition setup ---
print_message "=== DEBUGGING PARALLEL SETUP ===" $YELLOW
print_message "Current working directory: $(pwd)" $GREEN
print_message "Contents of current directory:" $GREEN
ls -la

# Check for decomposeParDict
DECOMPOSE_DICT="system/decomposeParDict"
if [ -f "$DECOMPOSE_DICT" ]; then
    print_message "Found $DECOMPOSE_DICT" $GREEN
    print_message "Contents of $DECOMPOSE_DICT:" $GREEN
    cat "$DECOMPOSE_DICT" | grep -E "(numberOfSubdomains|method)" || echo "Could not find numberOfSubdomains or method"
    
    # Extract numberOfSubdomains from decomposeParDict
    DICT_PROCS=$(grep -E "numberOfSubdomains\s+" "$DECOMPOSE_DICT" | sed 's/[^0-9]*//g')
    if [ -n "$DICT_PROCS" ]; then
        print_message "numberOfSubdomains in decomposeParDict: $DICT_PROCS" $GREEN
    else
        print_message "Could not extract numberOfSubdomains from decomposeParDict" $RED
    fi
else
    print_message "WARNING: $DECOMPOSE_DICT not found!" $RED
fi

# Count existing processor directories
PROCESSOR_DIRS=$(ls -d processor* 2>/dev/null | wc -l)
if [ $PROCESSOR_DIRS -gt 0 ]; then
    print_message "Found $PROCESSOR_DIRS processor directories:" $GREEN
    ls -d processor* 2>/dev/null
else
    print_message "No processor directories found. Case might not be decomposed." $YELLOW
    print_message "Available directories:" $GREEN
    ls -d */ 2>/dev/null || echo "No directories found"
fi

# Compare values
print_message "=== COMPARISON ===" $YELLOW
print_message "MPI processes requested: $MPI" $GREEN
print_message "Processor directories found: $PROCESSOR_DIRS" $GREEN
print_message "decomposeParDict numberOfSubdomains: ${DICT_PROCS:-'NOT_FOUND'}" $GREEN

# Check if decomposition is needed
if [ $PROCESSOR_DIRS -eq 0 ] && [ "$MPI" -gt 1 ]; then
    print_message "No processor directories found but MPI > 1. Running decomposePar..." $YELLOW
    decomposePar
    DECOMPOSE_EXIT_CODE=$?
    if [ $DECOMPOSE_EXIT_CODE -ne 0 ]; then
        print_message "decomposePar failed (Exit Code: $DECOMPOSE_EXIT_CODE). Exiting." $RED
        exit $DECOMPOSE_EXIT_CODE
    fi
    # Recount processor directories after decomposition
    PROCESSOR_DIRS=$(ls -d processor* 2>/dev/null | wc -l)
    print_message "After decomposePar: Found $PROCESSOR_DIRS processor directories" $GREEN
fi

# Final validation
if [ "$MPI" -gt 1 ] && [ $PROCESSOR_DIRS -ne $MPI ]; then
    print_message "ERROR: Mismatch detected!" $RED
    print_message "  MPI processes: $MPI" $RED
    print_message "  Processor directories: $PROCESSOR_DIRS" $RED
    print_message "  Please ensure your case is properly decomposed for $MPI processes." $RED
    exit 1
fi
# --- End Debugging ---

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
    zip -q -r "/workdir/$ZIP_OUTPUT_FOLDER" "OpenFoam/$EXTRACTED_DIR" || {
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
