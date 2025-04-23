# Docker-OpenFoam
Build the images:
```bash
# Build the base image (if needed, usually pulled from Docker Hub)
# docker build -t satcomx00/openfoam-base:latest -f Dockerfile.openfoam .

# Build the runner image
docker build -t satcomx00/openfoam-runner:latest -f Dockerfile .
```

## Running the Container

You need to set environment variables when running the container. Mount your input zip file to `/workdir` inside the container.

**Required Environment Variables:**

*   `MPI=4` (Number of MPI processes)
*   `MODE=interFoam` (Solver/Mode, case-sensitive)
*   `ARGUMENTS=-parallel` (Arguments for the solver, e.g., `-parallel`)
*   `ZIP_ARCHIVE_INPUT=your_input_archive.zip` (The **name** of your zip file located in `/workdir`)

**Example `docker run` command:**

```bash
docker run --rm \
  -v /path/to/your/local/data:/workdir \
  -e MPI=4 \
  -e MODE=interFoam \
  -e ARGUMENTS="-parallel" \
  -e ZIP_ARCHIVE_INPUT="damBreak_Finer_4mpi.zip" \
  satcomx00/openfoam-runner:latest
```

**Input File:**

*   Your OpenFOAM case files must be inside a zip archive (e.g., `damBreak_Finer_4mpi.zip`).
*   Place this zip file in the directory you mount to `/workdir`.
*   Set `ZIP_ARCHIVE_INPUT` to the **filename** of this zip archive.

**Output:**

*   The container will unzip the input archive into `/workdir/OpenFoam/`.
*   It will run the specified solver (`MODE`) inside the extracted case directory. Note: `blockMesh` is **not** automatically executed by this script. Ensure your case is meshed beforehand or includes meshing steps in a custom script if needed.
*   If successful, the entire extracted case directory (including results) will be zipped into a file named `<input_zip_basename>-output.zip` (e.g., `damBreak_Finer_4mpi-output.zip`) inside `/workdir`. This output zip file will be available in your mounted local directory after the container finishes.

**Notes:**

*   The OpenFOAM environment (`/opt/openfoam11/etc/bashrc`) is automatically sourced when the container starts.
*   MPI optimized : `ulimit -s unlimited ; ulimit -v unlimited` is set within the entrypoint script.

https://github.com/Satcomx00-x00/docker-openfoam