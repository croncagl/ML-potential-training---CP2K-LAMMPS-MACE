#!/bin/bash -l

#SBATCH --job-name=scf
#SBATCH --time=02:00:00           # HH:MM:SS walltime per SCF
#SBATCH --nodes=1                 # one node per array task
#SBATCH --ntasks-per-core=1
#SBATCH --ntasks-per-node=32       # 4 MPI ranks per node
#SBATCH --cpus-per-task=8         # 4 OMP threads per rank
#SBATCH --account=your_account    # CHANGE YOUR ACCOUNT HERE
#SBATCH --hint=nomultithread      # disable hyperthreading
#SBATCH --exclusive               # reserve the node exclusively
#SBATCH --no-requeue
#SBATCH --uenv=cp2k/2026.1:v2
#SBATCH --view=cp2k
#SBATCH --array=0-29              # launch 30 independent tasks


#  environment setup 

export CUDA_CACHE_PATH="/dev/shm/$USER/cuda_cache" 
export MPICH_GPU_SUPPORT_ENABLED=1
export MPICH_MALLOC_FALLBACK=1
export OMP_NUM_THREADS=$((SLURM_CPUS_PER_TASK - 1))

# ADDED - these stop the crashing due to the large number of jobs launched in the array
export OMP_PLACES=cores
export OMP_PROC_BIND=close

ulimit -s unlimited

# path to CP2K binary & input base name
EXE=/user-environment/env/cp2k/bin/cp2k.psmp
INP=sp

# map the array index to the folder name (0000…0019)
i=$(printf "%04d" "$SLURM_ARRAY_TASK_ID")
cd $i

# launch exactly one SCF here
srun --ntasks-per-node=$SLURM_NTASKS_PER_NODE --cpus-per-task=$SLURM_CPUS_PER_TASK --cpu-bind=cores /your_path_to/mps-wrapper.sh ${EXE}  -i ${INP}.inp -o ${INP}.out
