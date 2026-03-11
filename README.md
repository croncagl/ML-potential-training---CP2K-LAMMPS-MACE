# DFT-ML-potential-training---CP2K-LAMMPS-MACE

This repository contains a suite of codes to train a Machine Learning potential on a Molecular Dynamics trajectory, that was run with either ab-initio MD or classic MD with a universal ML potential or classical field.

# Installation

The installation steps reported here partially refer to the [Alps](https://docs.cscs.ch/alps/) infrastructure of CSCS. You will have to change accordingly to your needs.

- CP2K: the software is already available on Alps via uenv. You can find CP2K images with the command `$ uenv image find cp2k` and then pull the latest (as per now 2026.1:v1) image via the command  
  `$ uenv image pull cp2k/2026.1:v1`  
After, download the `mps-wrapper.sh` script available [here](https://docs.cscs.ch/running/slurm/#multiple-ranks-per-gpu) and place it in a safe permanent folder.
  More information about CP2K on Alps can be found on this [page](https://docs.cscs.ch/software/sciapps/cp2k/).
- LAMMPS+MACE: Following the section "LAMMPS with MACE" at the end of this [page](https://docs.cscs.ch/software/sciapps/lammps/#lammps-ml-iap-using-lammps-with-machine-learning-interatomic-potentials), you will have to run the following commands:
  ```
  $ uenv image pull lammps/20251210:v2
  $ uenv start --view kokkos lammps/20251210:v2
  $ python -m venv --system-site-packages my-venv-lammps-mace  #change name here if you want and accordingly eveywhere else in the scripts
  $ source my-venv-lammps-mace/bin/activate
  $ pip install --upgrade pip
  $ pip install torch --index-url https://download.pytorch.org/whl/cu129
  $ pip install mace-torch cuequivariance-torch cuequivariance cuequivariance-ops-torch-cu12 cupy-cuda12x
  ```

# Workflow description

To train a ML interatomic potential on a DFT-labeled MD trajectory, these steps are needed:
1) MD simulation
2) SCF labelling
3) Training
4) Active Learning

# 1. MD simulation

The first step is to run a MD simulation. There are two options:  
1a) AIMD-CP2K (ab initio MD with CP2K)  
1b) MD-LAMMPS (classical MD with LAMMPS)

## 1a) AIMD-CP2K

This folder contains these scripts:
- `md.inp` is the CP2K input file for the ab initio molecular dynamics simulation
- `md_scf.inp` is the CP2K input file for the single point calculation needed by the ab initio molecular dynamics simulation
- `run_md.sh` is the SLURM script for the MD simulation
- `run_md_scf.sh` is the SLURM script for the single point calculation

These scripts run a Second-Generation Car-Parrinello Molecular Dynamics.  
After changing all the settings in the input files `md.inp`and `md_scf.inp` according to your system (i.e. coordinates file, cell parameters, temperature, timestep, pseudopototentials, cutoffs, ..., more info [here](https://manual.cp2k.org/trunk/CP2K_INPUT.html)), run the calculation with  
`$ sbatch run_md.sh`  
After the simulation runs a certain number of steps, specified in the input file with `STEPS` in the `&MD` section, the job ends, and the single point set in `md_scf.inp` is automatically launched via `run_md_scf.sh`.
Then, the MD simulation restarts using the new wavefunction obtained after the precise SCF, and so on until stopped manually.
   > **Note:** Ensure the single point calculation directed by the input file `md_scf.inp` has stringent convergence criterions. This will help the simulation to stay on a reasonable trajectory, pulling down the electorn density to the ground state one each `STEPS` steps.

The simulation will produce trajectory file in a standard `.xyz` format:  
```
    1134  
 i =       76, E =    -40112.8815259092    
 Ti        -0.0374626618        1.6857316351       10.5523764451  
 Ti        -1.5426703813        4.2979402306       10.5567939505  
 Ti        -3.0538668963        6.9167098490       10.5380119194  
 Ti        -4.5623026327        9.5329102802       10.5231414480  
 Ti        -6.0740407861       12.1483415934       10.5395817632  
 Ti        -7.5813214901       14.7636733252       10.5415791306  
 Ti         2.9817163569        1.6823293923       10.5409873864  
 Ti         1.4702047842        4.2955845747       10.5580510520  
 Ti        -0.0358090963        6.9152884536       10.5378224025  
 Ti        -1.5433445710        9.5313615008       10.5296709956  
 Ti        -3.0555195063       12.1468966215       10.5431411195  
 Ti        -4.5651863866       14.7630269852       10.5479966274  
 Ti         6.0011354332        1.6798836881       10.5485150394  
 Ti         4.4915020773        4.2955538760       10.5404620587  
 Ti         2.9815548741        6.9157585884       10.5329503972  
 Ti         1.4730927629        9.5316746948       10.5395791049  
 Ti        -0.0378415659       12.1496751513       10.5439065695
...
```
where the various snapshots `i` of the simulations are printed sequentially in the file.

## 1b) MD-LAMMPS

Since ab initio MD simulations (such as the one done with CP2K) can be computationally demanding (in both time and cost), an alternative is provided by running a classical molecular dynamics simulation with a so-called universal model, or foundation model, which describes fairly accurately the interactions between atoms of many different species. In this case we refer to the MACE foundation models, that are extensively described [here](https://github.com/ACEsuit/mace-foundations).  
If you plan to use one of these models, first make sure to convert it to the right LAMMPS format. To do this, exit any uenv/venv loaded on a login node, and then run these commands 
```
$ salloc -A <your_account> -C gpu -N 1 -t 00:05:00
$ srun --pty /bin/bash
$ uenv start --view kokkos lammps/20251210:v2
$ source my-venv-lammps-mace/bin/activate
$ python -m mace.cli.create_lammps_model mace.model --format=mliap
```

The `MD-LAMMPS` folder contains these scripts:  
- `input.lammps`: example LAMMPS input file ([here](https://docs.lammps.org/Run_formats.html#input-file) other details) for a MD simulation with a MACE potential
- `run_lammps_mace_slurm`: SLURM script for launching the LAMMPS MD input file

After having created the `geom.lmp` file which is a file containing the information about the system under investigation (coordinates, masses, cell, ... [here](https://docs.lammps.org/Run_formats.html#data-file) the documentation) and after having modified the input file `input.lammps` accordingly to your system properties and simulation details, run the MD simulation with  
`$ sbatch run_lammps_mace_slurm`  
Also in this case, the simulation will produce a trajectory file in a standard `.xyz` format, as requested by the `dump` command in the `input.lammps` input file.

# 2. SCF labelling
When the MD is done, the next step is to "label" a subset of the trajectory with single point calculations to calculate DFT energies and forces. This will ultimately produce the training set that will be used by MACE to create the ML interatomic potential.   
The folder `SCF` contains the following scripts:

- `sp.inp`: CP2K input file for a single point calculation. This must have the desired level of theory for the ML potential.
- `select_configs.py`: python script to select random configurations from a trajectory and set up the filesystem. It also contains a couple of functions to delete atoms or molecules above a certain height, and modify the multiplicity of `sp.inp` according to the number of electrons.
- `orig_submit.sh`: SLURM script to launch an array of single point calculations
- `copy_submit.py`: python script to copy the original SLURM script to each folder, and adjust the array numbers
- `make_extended_mace.sh`: shell script to extract energy, coordinates, and forces from each selected configuration, and compile them in a single file ready for training.
 
The labelling must be done following these instructions:  

0. Put your `.xyz` trajectory file in the `SCF` folder.
1. Adjust borders, number of configurations, and number of folders in the `select_configs.py` script. This creates a folder named `sp_conf`, which contains a number of folders equal to that specified in the script, each containing the same number of subfolders. Each subfolder, numbered progressively from 0000 to the total number, contains the `.xyz` file of the randomly extracted configuration and a copy of the `sp.inp` file. 
   An example of the directory tree, for 3 folders with 50 configurations each (150 configurations total) would be
   ```text
    sp_conf/
	├── indices.npy
		├── 0/
		│   ├── 0000/
		│   │   ├── geom.xyz
		│   │   └── sp.inp
		│   ├── ⋮
		│   ├── 0049/
		│   └── submit_0_00.sh
		├── 1/
		│   ├── 0050/
		│   ├── ⋮
		│   ├── 0099/
		│   └── submit_1_00.sh
		└── 2/
		    ├── 0100/
		    ├── ⋮
		    ├── 0149/
		    └── submit_2_00.sh
   ```
2. Adjust the number of folders and configurations in the `copy_submit.py` script, then use it. This puts a copy of the `orig_submit_0_00.sh` file in each of the folders of `sp_conf`, and adjusts the array numbers accordingly. It also creates the `submit_all.sh` script.
3. Use `bash submit_all.sh` script to launch all the single points at once. The single points are all launched on different nodes, there should be no issue with crashing due to memory problems.
4. When all the SCF have been completed, use the `make_extended_mace.sh` script, also adjusting the number of folders, to automatically extract energy, coordinates, and forces from each configuration, and convert energies from Hartree to eV, and forces from Hartree/Bohr to eV/Angstrom. This file can be used as a training set, or added to the existing training set.
> **Warning:** Pay attention to adjust the cell that is being used in all the files that require it: `sp.inp`, `select_configs.py`, `make_extended_mace.sh`


# 3. Training

Once the `make_extended_mace.sh` script has constructed the training data file, the training can start.  
To do this, simply put your training set file in the `Training` folder, where the `run_mace.sh` script is, and run it with   
`$ sbatch run_mace.sh`  
Once the training is finished, convert the created `.model` file in the LAMMPS format. To do this, exit any uenv/venv loaded on a login node, and then run these commands 
```
$ salloc -A <your_account> -C gpu -N 1 -t 00:05:00
$ srun --pty /bin/bash
$ uenv start --view kokkos lammps/20251210:v2
$ source my-venv-lammps-mace/bin/activate
$ python -m mace.cli.create_lammps_model mace.model --format=mliap
```
The model can be used now to run MD simulations with LAMMPS as described in section 1b).

# 4. Active Learning
- `std_max.py` is the python script which calculates the maximum standard deviation of the forces, among all atoms for each configuration, and among all models. 
- `run_stdev` is the SLURM script to run the `std_max.py` script
- `conf_selection.ipynb` is a Jupyter notebook template to analyze the maximum standard deviation histograms, and select a number of configurations based on standard deviation.

To do active learning, create a committee of 4 models, using the same training set but different seed, then run a molecular dynamics simulation using one of them.
Insert the path to each model in the `std_max.py` script, along with the path to the trajectory (in `.xyz` format), then sbatch `run_stdev`. After the job is completed, put the trajectory and the file `model_devi.out` that has been produced in a folder, and use the `conf_selection.ipynb` notebook to analyze the force deviation histogram.
