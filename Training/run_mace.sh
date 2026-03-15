#!/bin/bash
#SBATCH --job-name=mace-torch-training
#SBATCH --nodes=1
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --ntasks-per-node=4
#SBATCH --gpus-per-node=4
#SBATCH --gpus-per-task=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:30:00
#SBATCH --account=your_account  #change here
#SBATCH --partition=normal
#SBATCH --uenv=lammps/20251210:v2
#SBATCH --view=kokkos
#SBATCH --exclusive

export MPICH_GPU_SUPPORT_ENABLED=1
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
ulimit -s unlimited

source /path_to_your/my-venv-lammps-mace/bin/activate  #change here

fixed_args=(
  --name="h2o"
  --seed=881311935
  --device='cuda'
  --enable_cueq=True
  --model='MACE'
  --error_table='PerAtomRMSE'
  --default_dtype='float32'
  --num_workers=$OMP_NUM_THREADS
  --r_max=6.0
  --num_channels=256
  --max_L=2
  --train_file="h2o_training.xyz"
  #--valid_file="val.xyz"
  #--test_file="test.xyz"
  --loss='weighted'
  #--config_type_weights '{"slab_clean":1,"slab_term":1,"slab_CO2":1,"gas":1,"molecule":1,"finetuning":1.0,"finetuning_h2co3":0.5,"big_slab_CO2":1}'
  --energy_key='REF_energy'
  --forces_key='REF_forces'
  --E0s="average"      # Isolated atom energies in the training file
  --restart_latest
  --distributed
  --forces_weight=100.0
  --energy_weight=1.0
  --batch_size=1
  --valid_batch_size=2
  --lr=0.01
  --max_num_epochs=100
  --eval_interval=1
  --swa
  --swa_lr=0.001
  --start_swa=75
)

echo "Running training..."
srun env LOCAL_RANK=0 SLURM_LOCALID=0 /path_to_your/my-venv-lammps-mace/bin/python -m mace.cli.run_train "${fixed_args[@]}" &
wait

deactivate
