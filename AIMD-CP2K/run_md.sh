#!/bin/bash -l

#SBATCH --job-name=MD_CP2K
#SBATCH --time=3:00:00           
#SBATCH --nodes=8                                                                        
#SBATCH --ntasks-per-core=1
#SBATCH --ntasks-per-node=32 
#SBATCH --cpus-per-task=8 
#SBATCH --account=your_account                                                                             
#SBATCH --hint=nomultithread                                                                           
#SBATCH --exclusive
#SBATCH --no-requeue
#SBATCH --uenv=cp2k/2026.1:v1
#SBATCH --view=cp2k
 
# set environment
export CUDA_CACHE_PATH="/dev/shm/$USER/cuda_cache" 
export MPICH_GPU_SUPPORT_ENABLED=1 
export MPICH_MALLOC_FALLBACK=1
export OMP_NUM_THREADS=$((SLURM_CPUS_PER_TASK - 1))
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
srun --cpu-bind=socket /path_to_your/mps-wrapper.sh cp2k.psmp -i md.inp -o md.out

# mark first run as complete
if [ ! -e "first_run.done" ]; then
    touch first_run.done
fi

# submit next job in chain
sbatch run_md_scf.sh
