#! /bin/bash
source /usr/lib/openfoam/etc/bashrc
echo "Starting...."
cd /workdir
ulimit -s unlimited ulimit -v unlimited
blockMesh
# mpiexec -n $MPI simpleFoam $FOAM_DIR_PATH
mpirun -np $MPI simpleFoam
# mpirun -np 2 simpleFoam