# Docker-OpenFoam
```
docker build -t openfoam-base:latest -f Dockerfile.openfoam .
docker build -t openfoam-runner:latest -f Dockerfile .
```


You need to add some env vars before starting, to make it well you need to configure :

```
MPI=4     # MPI
```
```
MODE=interFoam        # Configure your Solver/Mode here (WARNING : Case Sensitive)
```
```
ARGUMENTS=-parallel          # Multiple args can be setted up in the same vars 
```
```
ZIP_ARCHIVE_INPUT=OpenFoam/damBreak_Finer_4mpi    # this is the path in your docker volume
```


- Container Configuration : 

You need to use a Zip file where all of your OpenFoam folder are in and set it as target of ZIP_ARCHIVE_INPUT without the ".zip".

auto sourcing : ```source /usr/lib/openfoam/etc/bashrc```

MPI optimized : ```ulimit -s unlimited ; ulimit -v unlimited```

A file named "****-output.zip" will be created in the container volume.


https://github.com/Satcomx00-x00/docker-openfoam