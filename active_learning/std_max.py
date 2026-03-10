import numpy as np
from ase.io import read, write
from mace.calculators.mace import MACECalculator
from tqdm import tqdm
import copy

# Input and output file paths
trajectory_file = "/capstor/scratch/cscs/sbrovell/mace/lammps/9ap_products_unbiased/both_hydrogenated_r/run4_200K_no_gas_pos_small_barrier/dump.xyz"  # Input trajectory file
output_file = "output.traj"  # Output trajectory file

# Model paths
ensemble_models = [
    "/capstor/scratch/cscs/sbrovell/mace/9AP/more_trainings_with_gas/E0s_set_trim6/swa/9ap_compiled.model",
    "/capstor/scratch/cscs/sbrovell/mace/9AP/more_trainings_with_gas/E0s_set_trim6_2/swa/9ap_compiled.model",
    "/capstor/scratch/cscs/sbrovell/mace/9AP/more_trainings_with_gas/E0s_set_trim6_3/swa/9ap_compiled.model",
    "/capstor/scratch/cscs/sbrovell/mace/9AP/more_trainings_with_gas/E0s_set_trim6_4/swa/9ap_compiled.model"
]

# Load trajectory
traj = read(trajectory_file, index=":")  # Read all configurations
print(f"INFO   | Read {trajectory_file} ({len(traj)}) configurations")

# Initialize MACE calculator
calc = MACECalculator(model_paths=ensemble_models, device="cuda", model_type="MACE")
print(f"INFO   | Model loaded: {calc}")

# Store global max deviations for each frame
global_max_deviations = []

max_deviations_per_atom = []

# Process trajectory
for i, atoms in enumerate(tqdm(traj, desc="Processing frames")):
    # Perform calculations
    calc.calculate(atoms)
    atoms.calc = copy.copy(calc)

    if calc.num_models > 1:
        # |mean| and standard deviation of forces over ensemble
        fstd = calc.results["forces_comm"].std(axis=0)

        # Calculate variance as maximum deviation per atom component
        max_deviation_per_atom = np.amax(fstd, axis=1)  # maximum of (x, y, z) per atom
        global_max_deviation = np.amax(max_deviation_per_atom)  #  maximum of all atoms

        # max deviation for the frame
        global_max_deviations.append(global_max_deviation)

        max_deviations_per_atom.append(max_deviation_per_atom)
        # max deviation per atom to the Atoms object
        atoms.set_array("force_std_comp_max", max_deviation_per_atom)

write(output_file, traj)
print(f"INFO   | Written {output_file} with {len(traj)} configurations")

with open("model_devi.log", "w") as f:
    for i, max_dev in enumerate(global_max_deviations):
        f.write(f"Frame {i + 1}: {max_dev}\n")
np.savetxt("model_devi_atomic.out",max_deviations_per_atom)
average_deviation = np.mean(max_deviations_per_atom, axis=1)
np.savetxt("model_devi_avg.out",average_deviation)
index_max = np.argmax(max_deviations_per_atom,axis=1).astype(int) # Save the index of the atom for which the deviation is maximal
np.savetxt("index_max.out",index_max,fmt="%d")
