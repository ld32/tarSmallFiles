#!/bin/bash

#set -x

[ $# -ne 2 ] && echo "Usage: $0 <sourceDir> <nProcess>" && exit 1



sDir=`realpath $1`

#if [ -z $4 ]; then 
    dDir=${sDir#*datasets/}
    #dFolder=${dFolder#*1TRaw/}
    dDir=${dDir//\//--}
    mkdir -p $dDir 


nJobs="$2"

folders="${dDir}Log/foldersSudo.txt"

[ -f $folders ] && echo Folder file already exist. Please delete it first: $folders && exit 1

#[ $level -lt 1 ] && echo Minimum folder level is 1. && exit 1

dFolderTmp=`mktemp -d`
tempFile=$(mktemp)
touch $tempFile.log

trap "rm -r $dFolderTmp $tempFile $tempFile.txt $tempFile.*.txt 2>/dev/null" EXIT

while true; do
    sudo -v
    sleep 300  # Refresh every 5 minutes
done &

echo $sDir > "$tempFile.0.txt"


echo "Working on first level..."

sudo find "$sDir" -mindepth 1 -maxdepth 1 -type d > "$tempFile" || echo "scan level 1 error shown above" >&2

x=$(wc -l < "$tempFile") 

if [ "$x" -lt 100 ]; then 
    cat "$tempFile" >> $tempFile.0.txt
    
    echo "Working on second level..." 
    sudo find "$sDir" -mindepth 2 -maxdepth 2 -type d > "$tempFile" || echo "scan level 2 error shown above" >&2
    x=$(wc -l < "$tempFile") 
    if [ "$x" -lt 100 ]; then 
        cat "$tempFile" >> $tempFile.0.txt
        
        echo "Working on third level..." 
        sudo find "$sDir" -mindepth 3 -maxdepth 3 -type d > "$tempFile" || echo "scan level 3 error shown above" >&2
    fi 
fi

echo "Finding all subfolders in parallel, limited to $nJobs concurrent processes..."
cat "$tempFile" | while IFS= read -r folder; do
    while true; do
        jobID=0
        for i in $(seq 1 $nJobs); do
            if `mkdir $dFolderTmp/lock.$i 2>/dev/null`; then
                jobID=$i
                break
            fi
        done
        [ "$jobID" -eq "0" ] && sleep 1 || break 
    done 
    (   #sleep 1
        echo "job $jobID $folder" | tee $tempFile.log
        sudo find "$folder" -type d >> "$tempFile.$jobID.txt" || echo "scan job $jobID error shown above" >&2
        rm -r "$dFolderTmp/lock.$jobID" 
     ) &
done

# doest not 
#wait

while true; do 

    [[ $sDir == *scratch* ]] && sleep 5 && break 
  
    current_time=$(date +%s)
    
    file_mod_time=$(stat -c %Y $tempFile.log)

    time_diff=$((current_time - file_mod_time))

    [ "$time_diff" -ge 300 ] && break 
    
    sleep 10
done 

#sleep 20
cat  $tempFile.*.txt > $tempFile.txt

sleep 5 
cp $tempFile.txt $folders

echo "All folders found:": 
cat $folders
