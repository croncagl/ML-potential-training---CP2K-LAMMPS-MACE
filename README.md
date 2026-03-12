# DFT-ML-potential-training---CP2K-LAMMPS-MACE

This repository contains a suite of codes to train a Machine Learning potential on a Molecular Dynamics trajectory, that was run with either ab-initio MD or classic MD with a universal ML potential or classical field.

# Installation

The installation steps reported here partially refer to the [Alps](https://docs.cscs.ch/alps/) infrastructure of CSCS. You will have to change accordingly to your needs.

- CP2K: the software is already available on Alps via uenv. You can find CP2K images with the command `$ uenv image find cp2k` and then pull the latest (as per now 2026.1:v1) image via the command  
  `$ uenv image pull cp2k/2026.1:v1`  
After, download the `mps-wrapper.sh` script available [here](https://docs.cscs.ch/running/slurm/#multiple-ranks-per-gpu) and place it in a safe permanent folder.
  More information about CP2K on Alps can be found on this [page](https://docs.cscs.ch/software/sciapps/cp2k/).
- LAMMPS+MACE: Following the section "LAMMPS with MACE" at the end of this [page](https://docs.cscs.ch/software/sciapps/lammps/#lammps-ml-iap-using-lammps-with-machine-learning-interatomic-potentials), you will have to create a dedicated virtual environment. Move to a safe and permament directory (such as `$STORE` or `$HOME`) and run the following commands:
  ```
  $ uenv image pull lammps/20251210:v2
  $ uenv start --view kokkos lammps/20251210:v2
  $ python -m venv --system-site-packages my-venv-lammps-mace  #change name here if you want and accordingly eveywhere else in the scripts
  $ source my-venv-lammps-mace/bin/activate
  $ pip install --upgrade pip
  $ pip install torch --index-url https://download.pytorch.org/whl/cu129
  $ pip install mace-torch cuequivariance-torch cuequivariance cuequivariance-ops-torch-cu12 cupy-cuda12x
  ```
  > **Warning:** Some scripts in the repository will have to source this virtual environment you just created. Therefore, before running, check that when this happens, you change the name and path accordingly.

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
- `water.xyz` a file containing the coordinates of 64 water molecules in a cubic box, that you can use as a test

These scripts run a Second-Generation Car-Parrinello Molecular Dynamics.  
If you are not running the test with water molecules, you must change all the settings in the input files `md.inp`and `md_scf.inp` according to your system (i.e. coordinates file, cell parameters, temperature, timestep, pseudopototentials, cutoffs, ..., more info [here](https://manual.cp2k.org/trunk/CP2K_INPUT.html)), and then run the calculation with  
`$ sbatch run_md.sh`  
After the simulation runs a certain number of steps, specified in the input file with `STEPS` in the `&MD` section, the job ends, and the single point set in `md_scf.inp` is automatically launched via `run_md_scf.sh`.
Then, the MD simulation restarts using the new wavefunction obtained after the precise SCF, and so on until stopped manually.
   > **Note:** Ensure the single point calculation directed by the input file `md_scf.inp` has stringent convergence criterions. This will help the simulation to stay on a reasonable trajectory, pulling down the electorn density to the ground state one each `STEPS` steps.

The simulation will produce trajectory file in a standard `.xyz` format:  
```
     192
 i =     1424, time =      712.000, E =     -1105.6736896936
  O         3.5337107104       -3.6887187243        5.0888985501
  H         3.0680039652       -4.1967370795        5.7867724170
  H         4.4603980763       -3.5235828804        5.3435138791
  O        -3.4599963468        1.7260212500        4.6924344265
  H        -3.9690158895        0.8943871846        4.4571245996
  H        -4.0114445010        2.0629840997        5.4279543292
  O         3.8132541531        3.6767210714       -7.6092879240
  H         2.8077912161        3.9505080695       -7.5088943994
  H         3.9071992980        2.7312972355       -8.0119714168
  O        -2.9465112092       -0.0914352224       -4.1691567879
  H        -2.3078910518        0.2395511044       -3.4738171345
  H        -2.3887447414       -0.7205677884       -4.6293317215
  O        -4.1349490504       -7.5162633190        5.6720183394
  H        -4.6028577825       -8.2738420126        6.1002481780
  H        -4.2329192090       -7.5961932706        4.6786529282
  O        -6.3643099029        0.4460789029        2.1358396511
  H        -5.7454751591       -0.2304906767        2.6165417730
  H        -5.8308345325        1.3052175224        2.0273909523
  O         5.5066525280       -3.8891911196        0.6268247593
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
- `water.lmp` a file containing the cell vectors as well as the masses and coordinates of 64 water molecules in a cubic box, that you can use as a test (same as `water.xyz` used in the CP2K MD)

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
