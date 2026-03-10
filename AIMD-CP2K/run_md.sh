#!/bin/bash -l

#SBATCH --job-name=MD_CP2K
#SBATCH --time=3:00:00           
#SBATCH --nodes=8                                                                        
#SBATCH --ntasks-per-node=8      # Number of MPI ranks per node
#SBATCH --cpus-per-task=8        # Number of OMP threads per rank
#SBATCH --account=your_account                                                                             
#SBATCH --hint=nomultithread                                                                           
#SBATCH --exclusive
#SBATCH --no-requeue
#SBATCH --uenv=cp2k/2025.1:v1
#SBATCH --view=cp2k
 
# set environment
export CP2K_DATA_DIR=/path_to_your_cp2k_data
export CUDA_CACHE_PATH="/dev/shm/$RANDOM"
export MPICH_GPU_SUPPORT_ENABLED=1
export MPICH_MALLOC_FALLBACK=1
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
ulimit -s unlimited

# change RESTART value appropriately
if [ -e "first_run.done" ]; then
    # for subsequent runs, set RESTART = 1
    sed -i 's/@SET *RESTART *[01]/@SET RESTART 1/' md.inp
    echo "setting RESTART = 1 for restart"
else 
    # for the first run, set RESTART = 0
    sed -i "s/@SET *RESTART *[01]/@SET RESTART 0/" md.inp
    echo "setting RESTART = 0 for initial run"
fi 
 
# run
srun --cpu-bind=cores /path_to_your/mps-wrapper.sh /user-environment/env/cp2k/bin/cp2k.psmp -i md.inp -o md.out

# mark first run as complete
if [ ! -e "first_run.done" ]; then
    touch first_run.done
fi

# submit next job in chain
sbatch run_md_scf.sh
