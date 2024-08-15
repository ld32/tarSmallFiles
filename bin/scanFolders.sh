#!/bin/bash

#set -x

[ $# -ne 4 ] && echo "Usage: $0 <nProcess> <sourceDir> <levelOfFistScan> <folderFile>" && exit 1

nJobs="$1"
sDir=`realpath $2`
dDir=`realpath $3`
level=$4

folders="${dDir}Log/folders.txt"

[ -f $folders ] && echo Folder file already exist. Please delete it first: $folders && exit 1

[ $level -lt 1 ] && echo Minimum folder level is 1. && exit 1

dFolderTmp=`mktemp -d`
tempFile=$(mktemp)
touch $tempFile.log

trap "rm -r $dFolderTmp $tempFile $tempFile.err $tempFile.txt 2>/dev/null" EXIT

echo $sDir > "$tempFile.txt"
echo "Finding folders up to $level levels deep in $sDir..."

if [ "$level" -gt 1 ]; then  
    for i in `seq 1 $((level -1))`; do 
        echo Adding level $i folder
        find "$sDir" -mindepth $i -maxdepth $i -type d >> "$tempFile.txt" || echo "scan level $i error shown above" >> $tempFile.err
        cat "$tempFile.txt"
    done 
fi     
echo Looking for level $level folders for paralele find command 
find "$sDir" -mindepth $level -maxdepth $level -type d >> "$tempFile" || echo "scan level $level error shown above" >> $tempFile.err
#cat "$tempFile" 

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
        find "$folder" -type d >> "$tempFile.txt" || echo "scan job $jobID error shown above" >> $tempFile.err
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

    [ "$time_diff" -ge 200 ] && break 
    
    sleep 1
done 

#sleep 20
cp $tempFile.txt $folders

echo "All folders found:": 
cat $folders

if [ -f $tempFile.err ]; then
    cat $tempFile.err >&2 
    exit 1 
fi