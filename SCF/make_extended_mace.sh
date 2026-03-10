#!/bin/bash

# Script to extract configuration, energy, and forces from each SCF, convert it to eV, and write them all in a file ready for model training
# I didn't touch the structure of this file at all

# Input variables for folder range
FOLDER_SIZE=20
BATCH_SIZE=3

# Conversion factors
hartree_to_ev=27.21139
hartree_per_bohr_to_ev_per_angstrom=51.42208

# Output file
output_file="big_slab.xyz"

# Initialize the output file
> "$output_file"

# Loop through all outer folders
for j in $(seq 0 $((BATCH_SIZE-1))); do
START=$((j*FOLDER_SIZE))
END=$(((j+1)*FOLDER_SIZE-1))
# Loop through all folders from START to END
for i in $(seq -f "%04g" "$START" "$END"); do
    folder="sp_conf/$j/$i"

    # Define file paths
    geom_file="$folder/geom.xyz"
    grad_file="$folder/Mo2Ti2C3-forces-1_0.xyz"
    tc_out_file="$folder/sp.out"

    # Check if required files exist
    if [[ -f "$geom_file" && -f "$grad_file" && -f "$tc_out_file" ]]; then
        # Read geom.xyz, skipping first 2 lines of grad.xyz
        geom_data=$(cat "$geom_file")
        grad_data=$(tail -n +3 "$grad_file")

        # Read energy from tc.out and convert to eV
        energy_hartree=$(grep "Total energy: " "$tc_out_file" | tail -n 1 | awk '{print $NF}')
        energy_ev=$(echo "$energy_hartree * $hartree_to_ev" | bc -l)

        # Read number of atoms
        Natm=$(head -n 1 "$geom_file")

        # Combine data
        echo "$Natm" >> "$output_file"
        echo "Lattice=\"36.228 0.00 0.00 -18.203 31.317 0.00 0.00 0.00 35.00\" Properties=species:S:1:pos:R:3:REF_forces:R:3 REF_energy=$energy_ev pbc=\"T T T\"" >> "$output_file"
        paste <(echo "$geom_data" | tail -n +3 | awk '{printf "%s %.8f %.8f %.8f\n", $1, $2, $3, $4}') \
              <(echo "$grad_data" | tail -n +2 | head -n $Natm | awk -v conv="$hartree_per_bohr_to_ev_per_angstrom" '{printf "%.8f %.8f %.8f\n", $3*conv, $4*conv, $5*conv}') \
              >> "$output_file"
    else
        echo "Warning: Missing required files in folder $folder"
    fi
done
done

# Inform completion
echo "Extended XYZ file created: $output_file"

