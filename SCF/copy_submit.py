# Script to copy the original submission script into the different folders, adjusting the number of configurations
# It also creates the 'submit_all.sh' script, which allows to start all the folders at once

import os
import shutil

input="orig_submit_0_00.sh"

### THESE TWO NUMBERS MUST BE THE SAME AS IN SELECT_CONFIG.PY ###
n_folders = 4
n_configs = 25

# Create multiple sbatch file
with open("submit_all.sh",'w') as f:
    f.write("#!/bin/bash -l\n")
    f.write("#SBATCH --job-name=submit_all\n")
    f.write("#SBATCH --time=00:02:00\n")
    f.write("#SBATCH --nodes=1\n")
    f.write("#SBATCH --account=lp86\n")
    f.write("#SBATCH --partition=normal\n")
    f.write("cd sp_conf\n")
    for _folder in range(n_folders):
        folder = f"{_folder}"
        f.write("cd {}\n".format(folder))
        with open(input,'r',encoding='utf-8') as file:
            data = file.readlines()
        for i_ in range(0,1):  #change according to final number of folders
            i=f"{i_:02}"

            with open("submit_"+folder+"_"+i+".sh",'w') as file:
                data[2]="#SBATCH --job-name=scf_"+str(folder)+"_"+i+"\n"
                for idx, line in enumerate(data):
                    if "#SBATCH --array=" in line:
                        data[idx] = f"#SBATCH --array={_folder*n_configs}-{(_folder+1)*n_configs-1}\n"
                file.writelines(data)
            #f.write("chmod +x submit_"+folder+"_"+i+".sh\n")
            f.write("sbatch submit_"+folder+"_"+i+".sh\n")

        f.write("cd ..\n")
        os.system("mv submit_"+folder+"* "+"sp_conf/"+folder)
