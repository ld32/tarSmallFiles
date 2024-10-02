#!/bin/bash

#SBATCH -p long
#SBATCH -t 10-00:00:00
#SBATCH --mem 5G
#SBATCH -c 2
#SBATCH --qos=testbump 
#SBATCH -J scanAll

for i in `cat allDFolders.txt`; do
    sDir=$i
    dDir=${sDir#*datasets/}
    echo $i

    dDir=${dDir//\//--}

    [ -f ${dDir}Log/folders.txt ] || echo no

    [ -d  ${dDir}Log ] && continue

    #echo -e "Submit job?(y)"
        
    #read -p "" x </dev/tty
    
        
    #[[ "$x" == y ]] || continue

    mkdir  ${dDir}Log && scanFolders.sh $i 5 > ${dDir}Log/$dDir.scan.log 2>&1
    
    #sbatch -A rccg --qos=testbump -o ${dDir}Log/$dDir.scan.log -J scan.$dDir -t 72:0:0 -p medium --mem 4G -c 2  --wrap="scanFolders.sh $i 5"; 

    #sleep 3600

done 

