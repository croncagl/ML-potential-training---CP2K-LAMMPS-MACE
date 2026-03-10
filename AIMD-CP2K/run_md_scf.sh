#!/bin/bash -l

#SBATCH --job-name=SCF_MD_CP2K
#SBATCH --time=04:00:00           # HH:MM:SS
#SBATCH --nodes=1
#SBATCH --ntasks-per-core=1                                                                        
#SBATCH --ntasks-per-node=4      # Number of MPI ranks per node
#SBATCH --cpus-per-task=4        # Number of OMP threads per rank
#SBATCH --account=your_account                                                                             
#SBATCH --hint=nomultithread                                                                           
#SBATCH --hint=exclusive
#SBATCH --no-requeue
#SBATCH --uenv=cp2k/2025.1:v1
#SBATCH --view=cp2k
 
# set environment
export CP2K_DATA_DIR=/path_to_your_cp2k_data
export CUDA_CACHE_PATH="/dev/shm/$RANDOM"
export MPICH_GPU_SUPPORT_ENABLED=1
export MPICH_MALLOC_FALLBACK=1
export OMP_NUM_THREADS=$((SLURM_CPUS_PER_TASK-1))
ulimit -s unlimited
 
# run
srun --cpu-bind=socket /path_to_your/mps-wrapper.sh /user-environment/env/cp2k/bin/cp2k.psmp -i md_scf.inp -o mx_scf.out
sbatch run_md.sh
