#!/bin/bash
#SBATCH --job-name=mace-torch
#SBATCH --nodes=4
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --ntasks-per-node=4
#SBATCH --gres=gpu:4
#SBATCH --cpus-per-task=36
#SBATCH --time=16:00:00
#SBATCH --account=lp86
#SBATCH --partition=normal
#SBATCH --uenv=pytorch/v2.6.0:/user-environment
#SBATCH --view=default
#################################
# OpenMP environment variables #
#################################
export OMP_NUM_THREADS=8
#################################
# PyTorch environment variables #
#################################
export MASTER_ADDR=$(hostname)
export MASTER_PORT=29400
export WORLD_SIZE=$SLURM_NPROCS
export TORCH_NCCL_ASYNC_ERROR_HANDLING=1
export TRITON_HOME=/dev/shm/
#################################
# MPICH environment variables   #
#################################
export MPICH_GPU_SUPPORT_ENABLED=0
#################################
# CUDA environment variables    #
#################################
export CUDA_CACHE_DISABLE=1
############################################
# NCCL and Fabric environment variables    #
############################################
export NCCL_NET="AWS Libfabric"
export NCCL_NET_GDR_LEVEL=PHB
export NCCL_CROSS_NIC=1
export FI_CXI_DISABLE_HOST_REGISTER=1
export FI_MR_CACHE_MONITOR=userfaultfd
export FI_CXI_DEFAULT_CQ_SIZE=131072
export FI_CXI_DEFAULT_TX_SIZE=32768
export FI_CXI_RX_MATCH_MODE=software

# Trying to fix OOM
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True


source /users/croncagl/mace-torch/bin/activate 

fixed_args=(
  --name="slab_finetuned"
  --seed=881311935
  --device='cuda'
  #--enable_cueq=True
  --model='MACE'
  --error_table='PerAtomRMSE'
  --default_dtype='float32'
  --num_workers=$OMP_NUM_THREADS
  --r_max=6.0
  --num_channels=256  
  --max_L=2
  --train_file="train.xyz"
  --valid_file="val.xyz"
  --test_file="test.xyz"
  --loss='weighted'
  --config_type_weights '{"slab_clean":1,"slab_term":1,"slab_CO2":1,"gas":1,"molecule":1,"finetuning":1.0,"finetuning_h2co3":0.5,"big_slab_CO2":1}'
  --energy_key='REF_energy'
  --forces_key='REF_forces'
  --E0s="isolated"      # Isolated atom energies in the training file
  --restart_latest
  --distributed
  --forces_weight=100.0
  --energy_weight=1.0
  --batch_size=1
  --valid_batch_size=2
  --lr=0.01
  --max_num_epochs=600
  --eval_interval=1
  --swa
  --swa_lr=0.001
  --start_swa=450
)

echo "Running training..."
srun mace_run_train "${fixed_args[@]}" &
wait

deactivate
