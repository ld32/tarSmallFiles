#!/bin/bash

set -x 

folderListFile=allDFolders.txt 
[ ! -f $folderListFile ] && echo "need fodler list file" && exit

# need make sure there is no pending 

for dFolder in `cat $folderListFile `; do 

    [ -d $dFolder ] || continue 

    logDir=${dFolder}LogT 
    [ -s $logDir/folders.txt ] || continue
    [ -f $logDir/allJobs.txt ] && continue

    while true; do
        IFS=$'\n'; count=`squeue -u $USER -t R,PD -o "%.18i %.2t" | wc -l`

        if [ "$count" -lt 100 ]; then 

            grep " \-J $dFolder " sbatchCommandsT.txt | while read -r line; do
               eval "$line"
               touch $logDir/allJobs.txt 
            done
            sleep 300
            break  
        else 
            sleep 900
        fi    
    done 
done 
