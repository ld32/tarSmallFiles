#!/bin/bash

# t=`squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R" -u $USER`
# echo -e "$t" | grep " R " 

# echo running: `echo -e "$t" | grep " R " | wc -l` 

# echo 


# #t=`squeue -t PD -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R" -u $USER`
# echo -e "$t" | grep PD  
# echo pending: `echo -e "$t" | grep PD | wc -l`


#set -x 

folderListFile=allDFolders.txt 
[ ! -f $folderListFile ] && echo "need fodler list file" && exit

export out=`squeue -u $USER -t PD,R -o "%.18i %.2t"`

while IFS= read -r dFolder; do
    # Your commands using $dFolder go here
     summarizeRun $dFolder; 

    echo -e "Quit? (q)"
    
    read -p "" x </dev/tty
    
    [[ "$x" == q ]] && exit 
done < "$folderListFile"
