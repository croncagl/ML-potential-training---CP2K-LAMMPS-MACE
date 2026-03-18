import os
import warnings
import logging
import numpy as np
import copy
from ase.io import read, write
from mace.calculators.mace import MACECalculator

# Mute PyTorch deprecation warnings and MACE dtype warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
logging.getLogger().setLevel(logging.ERROR)

# Get the SLURM process ID (defaults to '0' if running locally)
proc_id = int(os.environ.get("SLURM_PROCID", "0"))

# Input and output file paths
trajectory_file = "/path_to_some/dump.xyz"  # path to some input trajectory file
output_file = "output.traj"  # Output trajectory file

# Model paths
ensemble_models = [
    "/path_to_some/model_1.model",
    "/path_to_some/model_2.model",
    "/path_to_some/model_3.model",
    "/path_to_some/model_4.model"
]

# Load trajectory
traj = read(trajectory_file, index=":")  # Read all configurations
total_frames = len(traj)

if proc_id == 0:
    print(f"INFO   | Read {trajectory_file} ({total_frames}) configurations", flush=True)

# Initialize MACE calculator
calc = MACECalculator(model_paths=ensemble_models, device="cuda", model_type="MACE")

if proc_id == 0:
    print(f"INFO   | Model loaded: {calc}", flush=True)
    print(f"INFO   | Starting calculation on {total_frames} frames...", flush=True)

# Store global max deviations for each frame
global_max_deviations = []
max_deviations_per_atom = []

# Process trajectory
for i, atoms in enumerate(traj):
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

    if proc_id == 0 and (i + 1) % 10 == 0:
        print(f"INFO   | Processed frame {i + 1}/{total_frames}", flush=True)

# Print the final frame count if it wasn't a multiple of 10
if proc_id == 0 and total_frames % 10 != 0:
    print(f"INFO   | Processed frame {total_frames}/{total_frames}", flush=True)

max_deviations_per_atom = np.array(max_deviations_per_atom)

# Calculate stats
average_deviation = np.mean(max_deviations_per_atom, axis=1)
index_max = np.argmax(max_deviations_per_atom, axis=1).astype(int)

if proc_id == 0:
    write(output_file, traj)
    print(f"INFO   | Written {output_file} with {total_frames} configurations", flush=True)

    with open("model_devi_summary.out", "w") as f:
        f.write(f"{'Frame':>8} | {'Max_Deviation':>15} | {'Avg_Deviation':>15} | {'Max_Atom_Index':>15}\n")
        f.write("-" * 65 + "\n")

        for i in range(len(global_max_deviations)):
            f.write(f"{i + 1:8d} | {global_max_deviations[i]:15.6f} | {average_deviation[i]:15.6f} | {index_max[i]:15d}\n")

    np.savetxt("model_devi_atomic.out", max_deviations_per_atom, fmt="%.6f")

    print("INFO   | Written model_devi_summary.out and model_devi_atomic.out", flush=True)
    print("INFO   | Calculation complete.", flush=True)
