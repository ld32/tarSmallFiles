#!/bin/bash


#SBATCH -p long
#SBATCH -t 14-00:00:00
#SBATCH --mem 5G
#SBATCH -c 1
#SBATCH --qos=testbump 
#SBATCH -J scanNewFolders
#set -x
#set -e

rootFolders=allDFolders.txt 
[ ! -f $rootFolders ] && echo "need fodler list file" && exit

target_date=$(date -d "2024-08-12" +%s)
while IFS= read -r rFolder; do
    
    folderListFile=${rFolder}Log033/folders.txt
    [ ! -f $folderListFile ] && echo "need fodler list file" && exit
    rm ${rFolder}Log033/newFolders.txt 2>/dev/null
    while IFS= read -r dFolder; do
        #/n/htem/.snapshot/o2_groups_htem_daily_2024-10-07_23-45/temcagt/datasets/pwd
        #dFolder=/n/htem/.snapshot/o2_groups_htem_daily_2024-10-07_23-45/temcagt/datasets/211122dOoceraeaMulti1269_r1084/sections
        dFolder="/n/htem/temcagt/${dFolder#*temcagt/}" # for group
        if [ -d "$dFolder" ]; then 
            mod_time=$(stat -c %Y "$dFolder")
            if [ "$mod_time" -gt "$target_date" ]; then
                echo "$dFolder" >> ${rFolder}Log033/newFolders.txt
            fi 
        else 
            echo "$dFolder" >> ${rFolder}Log033/goneFolders.txt
        fi 
        #exit 
    done < "$folderListFile"
done < "$rootFolders"



