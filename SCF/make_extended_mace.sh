#!/bin/bash

#SBATCH --time=00:05:00

# Script to extract configuration, energy, and forces from each SCF, convert it to eV, and write them all in a file ready for model training

# Input variables for folder range
FOLDER_SIZE=25                                             #CHANGE HERE AS IN OTHER SCRIPTS
BATCH_SIZE=4

# Conversion factors
hartree_to_ev=27.21139
hartree_per_bohr_to_ev_per_angstrom=51.42208

# Output file
output_file="h2o_training.xyz"

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
        grad_file="$folder/H2O-forces-1_0.xyz"    #CHANGE HERE
        tc_out_file="$folder/sp.out"

        # Check if required files exist
        if [[ -f "$geom_file" && -f "$grad_file" && -f "$tc_out_file" ]]; then

            # Read energy from tc.out and convert to eV
            energy_hartree=$(grep "Total energy: " "$tc_out_file" | tail -n 1 | awk '{print $NF}')
            energy_ev=$(echo "$energy_hartree * $hartree_to_ev" | bc -l)

            # Read number of atoms directly from geom.xyz
            Natm=$(head -n 1 "$geom_file")

            # Write header to extended XYZ
            echo "$Natm" >> "$output_file"
            echo "Lattice=\"12.42 0.00 0.00 0.0 12.42 0.00 0.00 0.00 12.42\" Properties=species:S:1:pos:R:3:REF_forces:R:3 REF_energy=$energy_ev pbc=\"T T T\"" >> "$output_file"

            # Combine coordinates and forces side-by-side
            # geom_file uses standard tail to skip 2 XYZ header lines
            # grad_file uses awk to strictly grab lines where column 1 is a number ($1 ~ /^[0-9]+$/) and there are 6 columns total
            paste <(tail -n +3 "$geom_file" | awk '{printf "%s %.8f %.8f %.8f\n", $1, $2, $3, $4}') \
                  <(awk -v conv="$hartree_per_bohr_to_ev_per_angstrom" 'NF==6 && $1 ~ /^[0-9]+$/ {printf "%.8f %.8f %.8f\n", $4*conv, $5*conv, $6*conv}' "$grad_file" | head -n "$Natm") \
                  >> "$output_file"
        else
            echo "Warning: Missing required files in folder $folder"
        fi
    done
done

# Inform completion
echo "Extended XYZ file created: $output_file"
