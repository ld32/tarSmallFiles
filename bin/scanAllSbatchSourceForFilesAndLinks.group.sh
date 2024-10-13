#!/bin/bash

set -x 

for i in `cat allDFolders.txt`; do
    sDir=$i
    dDir=${sDir#*datasets/}
    echo $i

    dDir=${dDir//\//--}

    [[ "$dDir" == *datasets ]] && dDir=smallFolders 

    [ -f ${dDir}LogD/folders.source.with.file.or.link.txt ] && continue 

    #[ -d  ${dDir}LogD ] && continue

    #echo -e "Submit job?(y)"
        
    sbatch /home/ld32/data/tarSmallFiles1/bin/jobScanFileAndLinksGroup.sh $dDir 
    #read -p "" x </dev/tty
    
done 





