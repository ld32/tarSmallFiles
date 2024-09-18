

# t=`squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R" -u $USER`
# echo -e "$t" | grep " R " 

# echo running: `echo -e "$t" | grep " R " | wc -l` 

# echo 


# #t=`squeue -t PD -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R" -u $USER`
# echo -e "$t" | grep PD  
# echo pending: `echo -e "$t" | grep PD | wc -l`






IFS=$'\n'; export out=`squeue -u $USER -t PD,R -o "%.18i %.2t"`

for dFolder in `cat allDFolders.txt `; do 
    #dFolder=aaronsBrain--sections
    summarizeRun $dFolder;  

    checkJobs $dFolder; 


  echo -e "Quit? (q)"
    
    read -p "" x </dev/tty
    
    [[ "$x" == q ]] && exit 

done

exit 


#!/bin/bash


# if [ "$dFolder" == /* ]; then 

#     [ ! -d "$dFolder" ] && echo Source folder not exist: $dFolder && usage

#     dFolder=`realpath $1`


#     dFolder=${dFolder#*datasets/}
#     #dFolder=${dFolder#*1TRaw/}
#     dFolder=${dFolder//\//--}
    
#     runtimeFile=${dFolder}Log/runTime.txt
# else 

    runtimeFile=${dFolder}Log/runTime.txt
# fi 

# [ -z $2 ] || runtimeFile=$2 

[ -f $runtimeFile ] || { echo Runtime file not exist: $runtimeFile; echo Usage: $0 destinationFolder; continue; }

notDone=''
if [ -f ${dFolder}Log/allJobs.txt ]; then 
    
    if [ ! -z "$out" ]; then 
        for line in `cat ${dFolder}Log/allJobs.txt`; do
            [[ "$out" == *$line* ]] && notDone="$line $notDone"
        done 
    fi     
fi 

if [ -z "$notDone" ]; then 
    echo All jobs are done ++++++++++++++++++++
else 
    echo -e "A run was started earlier on the folder and the folowing jobs are still pending or running\nDo you want to cancel them (y)?\n$notDone"; 
    read -p "" x </dev/tty
    if [[ "$x" == y ]]; then 
        IFS=' ' 
        for id in $notDone; do 
            echo $id; scancel $id 
            sleep 0.5
        done 
    fi 
fi

    echo -e "Quit? (q)"
    
    read -p "" x </dev/tty
    
    [[ "$x" == q ]] && exit 


done