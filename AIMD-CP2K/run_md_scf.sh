#!/bin/bash -l

#SBATCH --job-name=SCF_MD_CP2K
#SBATCH --time=04:00:00           # HH:MM:SS
#SBATCH --nodes=1
#SBATCH --ntasks-per-core=1                                                                        
#SBATCH --ntasks-per-node=32      # Number of MPI ranks per node
#SBATCH --cpus-per-task=8        # Number of OMP threads per rank
#SBATCH --account=your_account                                                                             
#SBATCH --hint=nomultithread                                                                           
#SBATCH --hint=exclusive
#SBATCH --no-requeue
#SBATCH --uenv=cp2k/2026.1:v1
#SBATCH --view=cp2k
 
# set environment
export CUDA_CACHE_PATH="/dev/shm/$USER/cuda_cache" 
export MPICH_GPU_SUPPORT_ENABLED=1 
export MPICH_MALLOC_FALLBACK=1
export OMP_NUM_THREADS=$((SLURM_CPUS_PER_TASK - 1))
ulimit -s unlimited
 
# run
srun --cpu-bind=socket /path_to_your/mps-wrapper.sh cp2k.psmp -i md_scf.inp -o md_scf.out
sbatch run_md.sh
