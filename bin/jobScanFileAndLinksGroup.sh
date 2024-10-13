#!/bin/bash

#SBATCH -p medium
#SBATCH -t 5-0:00:00
#SBATCH --mem 5G
#SBATCH -c 1
#SBATCH --qos=testbump 
#SBATCH -J scanFiles
   
#read -p "" x </dev/tty
dDir=$1
while IFS= read -r dFolder; do
    # Your commands using $dFolder go here
    if [[ "$dDir" == smallFolders ]]; then 
        dFolder=${dFolder#*smallFolders/}
        dFolder=/n/htem/.snapshot/o2_groups_htem_daily_2024-10-02_23-45/temcagt/datasets/$dFolder
    else 
        dFolder=${dFolder#*ld32/}
        dFolder=${dFolder//--/\/}
        dFolder=/n/htem/.snapshot/o2_groups_htem_daily_2024-10-02_23-45/temcagt/datasets/$dFolder
    fi 
    if find "$dFolder" -maxdepth 1 -type f -o -type l | grep -q .; then
        echo "$dFolder" >> ${dDir}LogD/folders.source.with.file.or.link.txt
    fi
    #sleep 2 

done < "${dDir}LogD/folders.txt" 





