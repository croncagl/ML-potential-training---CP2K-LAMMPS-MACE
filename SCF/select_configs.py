# Script to select configurations from a MD trajectory.

from ase import atoms
from ase.io.trajectory import Trajectory
from ase.io import read
from ase.io import write
from ase.neighborlist import neighbor_list
import shutil
import numpy as np
import random
import os

########### Functions ############
def remove_floating_atoms(atoms, max_above, element='Mo'):
    """Remove atoms more than 'max_above' A above the highest atom of type 'element'."""
    
    positions = atoms.get_positions()
    symbols = atoms.get_chemical_symbols()

    # Step 1: Get max z of all Mo atoms
    mo_z = [pos[2] for pos, sym in zip(positions, symbols) if sym == element]
    if not mo_z:
        raise ValueError(f"No atoms of type {element} found.")

    z_threshold = max(mo_z) + max_above

    # Step 2: Filter atoms
    keep_indices = [i for i, pos in enumerate(positions) if pos[2] <= z_threshold]

    return atoms[keep_indices]

def remove_floating_molecules(atoms, max_above, element='Mo', cutoff=1.3):
    """
    Remove molecules more than 'max_above' A above the highest atom of type 'element'.
    This function uses the `ase.neighborlist` module so that if at least one atom of 
    the molecule is below the threshold, the whole molecule is kept.
    """
    import numpy as np

    positions = atoms.get_positions()
    symbols = atoms.get_chemical_symbols()

    # Get slab height
    mo_z = [pos[2] for pos, sym in zip(positions, symbols) if sym == element]
    if not mo_z:
        raise ValueError(f"No atoms of type '{element}' found.")
    z_threshold = max(mo_z) + max_above

    # Build adjacency list from neighbor list
    i, j = neighbor_list('ij', atoms, cutoff)
    num_atoms = len(atoms)
    adjacency = [[] for _ in range(num_atoms)]
    for a, b in zip(i, j):
        adjacency[a].append(b)
        adjacency[b].append(a)

    # Find connected components (molecules) using DFS
    visited = [False] * num_atoms
    molecule_ids = [-1] * num_atoms
    current_mol = 0

    def dfs(atom_index):
        stack = [atom_index]
        while stack:
            i = stack.pop()
            if not visited[i]:
                visited[i] = True
                molecule_ids[i] = current_mol
                stack.extend(adjacency[i])

    for idx in range(num_atoms):
        if not visited[idx]:
            dfs(idx)
            current_mol += 1

    # Keep molecules with any atom under threshold
    keep_mol_ids = set()
    for mol_id in range(current_mol):
        indices = [i for i, m in enumerate(molecule_ids) if m == mol_id]
        if any(positions[i][2] <= z_threshold for i in indices):
            keep_mol_ids.add(mol_id)

    keep_indices = [i for i, m in enumerate(molecule_ids) if m in keep_mol_ids]

    return atoms[keep_indices]

def modify_cp2k_input(file_path, Ne):
    '''
    Function to change MULTIPLICITY according to number of electrons

    :param file_path: path of the sp.inp file
    :param Ne: number of electrons
    '''
    with open(file_path, 'r') as f:
        lines = f.readlines()

    new_lines = []
    for line in lines:
        # Replace only if number of electrons is even 
        if (Ne) % 2 == 0:
            if line.strip().upper() == "LSD":
                new_lines.append("  UKS .FALSE.\n")
            elif line.strip().upper().startswith("MULTIPLICITY"):
                new_lines.append("  MULTIPLICITY 1\n")
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)

    with open(file_path, 'w') as f:
        f.writelines(new_lines)
##################################

writing_geoms = True
clear_first = False
inp = "sp.inp"

# Looking at the trajectory, I divide in bins and take a few trajectories from each bin to do single-point energy calculations

folder = "sp_conf"
traj_file = "dump.xyz"

# Eventually remove pre existing sp_conf folder
if os.path.exists(folder) and clear_first:
   shutil.rmtree(folder)

if not os.path.exists(folder):
    os.mkdir(folder)

# Read trajectory file
traj = read(traj_file, index = ":")
num_configs_in = len(traj)

#borders = np.linspace(0, num_configs_in, 6, dtype=int)   # 5 intervals in total  # use this line for equally spaced intervals

# Custom borders
borders = np.array([0, 200, 400, 600, 800, 1000])    # use this line to set borders manually

#total_configs = 170
num_bins = len(borders) - 1
#configs_per_bin = int(total_configs/num_bins)      # same number of configurations in each interval
configs_per_bin = np.array([5, 15, 10, 25, 5])     # custom number of configurations in each interval

print(borders)

print(configs_per_bin)

# if there has already been a selection process, read the indices.npy file produced during the process and exclude those indices from the selection
if os.path.exists('../indices.npy'):
    excluded_indices = set(np.load('../indices.npy'))
else:
    excluded_indices = set()

if writing_geoms:
    indices = np.zeros(sum(configs_per_bin),dtype=int)
    nconf = 0
    for i in range(num_bins):
        start = borders[i]
        end = borders[i+1]
        indices_range = set(range(start, end))
        available_indices = list(indices_range - excluded_indices)
        indices_chosen = random.sample(available_indices,configs_per_bin[i])
        indices[nconf:nconf+configs_per_bin[i]] = indices_chosen
        nconf += configs_per_bin[i]
        
    indices = np.sort(indices)

    print(indices)

    if os.path.exists('../indices.npy'):
        np.save(os.path.join(folder, "indices_new.npy"),indices)
    else:
        np.save(os.path.join(folder, "indices.npy"),indices)
    
config_num = 0
conf_per_folder = 20
num_folders = 3

for i in range(num_folders):
    bin_folder = os.path.join(folder ,str(i))
    if not os.path.exists(bin_folder):
        os.mkdir(bin_folder)

    for j in range(conf_per_folder):
        config_folder = os.path.join(bin_folder, f"{config_num:04}")
        if not os.path.exists(config_folder):
            os.mkdir(config_folder)
        if writing_geoms:
            index = indices[j + conf_per_folder*i]
            config = traj[index]
            config.set_pbc([True,True,False])
            config.set_cell([[36.228, 0.0000, 0.0000], [-18.203, 31.317, 0.0000], [0.0000,0.0000,35.0000]]) #change cell accordingly
            # Apply PBC
            config.set_positions(config.get_positions(wrap=True))
            # Remove floating molecules
            #config = remove_floating_molecules(config,max_above=8.0)
            # Write the configuration to file
            write(os.path.join(config_folder,"geom.xyz"),config)
        shutil.copyfile(inp,os.path.join(config_folder,"sp.inp"))
        # Change UKS and MULTIPLICITY in sp.inp according to the number of electrons N_e in the system 
        N_e = int(config.numbers.sum())
        modify_cp2k_input(os.path.join(config_folder,"sp.inp"), N_e)
        config_num += 1
