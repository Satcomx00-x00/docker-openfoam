#! /bin/bash
source /usr/lib/openfoam/etc/bashrc
echo "Starting...."

ulimit -s unlimited ulimit -v unlimited
# mpiexec -n $MPI simpleFoam $FOAM_DIR_PATH
mpirun -np $MPI simpleFoam $FOAM_DIR_PATH
# mpirun -np 2 simpleFoam