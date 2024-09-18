#!/bin/bash

#set -x

set -e

[ $# -ne 2 ] && echo "Usage: $0 <sourceDir> <nProcess>" && exit 1

sDir=`realpath $1`

#if [ -z $4 ]; then 
    dDir=${sDir#*datasets/}
    #dFolder=${dFolder#*1TRaw/}
    dDir=${dDir//\//--}
    mkdir -p $dDir ${dDir}Log
nJobs="$2"

folders="${dDir}Log/folders.txt"

[ -f $folders ] && echo Folder file already exist. Please delete it first: $folders && exit 1

dFolderTmp=`mktemp -d`
tempFile=$(mktemp)

trap "rm -r $dFolderTmp $tempFile $tempFile.txt  $tempFile.*.err $tempFile.*.txt 2>/dev/null" EXIT

echo $sDir > "$tempFile.0.txt"

for i in {1..10}; do 
    echo "Working on ${i}th level..."

    find "$sDir" -mindepth $i -maxdepth $i -type d > "$tempFile" 2>> $tempFile.0.err || echo "scan level $i error shown above" >>$tempFile.0.err

    x=$(wc -l < "$tempFile") 
    [ "$x" -lt 100 ] && [ "$x" -gt 0 ] || break

    cat "$tempFile" >> $tempFile.0.txt
done 

echo "Finding all subfolders in parallel, limited to $nJobs concurrent processes..."
cat "$tempFile" | while IFS= read -r folder; do
    #echo working on $folder 
    while true; do
        jobID=0
        for i in $(seq 1 $nJobs); do
            if `mkdir $dFolderTmp/lock.$i 2>/dev/null`; then
                jobID=$i
                break
            fi
        done
        [ "$jobID" -eq "0" ] && sleep 0.5 || break 
    done 
    (   #sleep 1
        echo "job $jobID $folder" 
        find "$folder" -type d >> "$tempFile.$jobID.txt" 2>> $tempFile.$jobID.err || echo "scan job $jobID error shown above" >> $tempFile.$jobID.err
        rm -r "$dFolderTmp/lock.$jobID" 
     ) &
done

# doest not 
#wait
sleep 5

while true; do 

    [[ $sDir == *scratch* ]] && sleep 5 && break 
  
    ls $dFolderTmp/lock.* 2>/dev/null && sleep 100  || break 
done 

cat  $tempFile.*.txt > $tempFile.txt

cp $tempFile.txt $folders

cat $tempFile.*.err >&2

echo "All folders found:": 

cat $folders
