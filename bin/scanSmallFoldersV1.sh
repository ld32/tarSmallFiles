#!/bin/bash

#set -x

#set -e

#[ $# -ne 2 ] && echo "Usage: $0 <sourceDir> <nProcess>" && exit 1

sDir=`realpath $1`

mkdir -p smallFolders smallFoldersLog
folders=smallFoldersLog/folders.txt #"${dDir}Log/folders.txt"

[ -f $folders ] && echo Folder file already exist. Please delete it first: $folders && exit 1

nJobs=1 

#[ $level -lt 1 ] && echo Minimum folder level is 1. && exit 1

dFolderTmp=$(mktemp -d /n/scratch/users/l/ld32/tmp.XXXXXX)

tempFile=$(mktemp)

trap "rm -r $dFolderTmp $tempFile $tempFile.txt  $tempFile.*.err $tempFile.*.txt 2>/dev/null" EXIT

# will keep them
echo $sDir > "$tempFile.0.txt"

echo "Working on first level..."
# for f in `find "$sDir" -mindepth 1 -maxdepth 1 -type d 2>> $tempFile.0.err || echo "scan level 1 error shown above" >> $tempFile.0.err`; do 
find "$sDir" -mindepth 1 -maxdepth 1 -type d 2>> $tempFile.0.err | while IFS= read -r f; do
    d=${f#*datasets/}
    d=${d//\//--}
    [ -d "$d" ] && echo ingnore $f && continue;
    echo $f >> "$tempFile.0.txt"
    echo "Working on second level..."
    find "$f" -mindepth 1 -maxdepth 1 -type d 2>> $tempFile.0.err | while IFS= read -r f1; do
        d1=${f1#*datasets/}
        d1=${d1//\//--}
        [ -d "$d1" ] && echo ingnore $f1 && continue;
        echo $f1 >> "$tempFile.0.txt"
        echo "Working on third level..."
        find "$f1" -mindepth 1 -maxdepth 1 -type d 2>> $tempFile.0.err | while IFS= read -r f2; do
            d2=${f2#*datasets/}
            d2=${d2//\//--}
            [ -d "$d2" ] && echo ingnore $f2 && continue;
            echo $f2 >> "$tempFile.0.txt"
            echo "Working on fouth level..."
            find "$f2" -mindepth 1 -maxdepth 1 -type d 2>> $tempFile.0.err | while IFS= read -r f3; do 
                d3=${f3#*datasets/}
                d3=${d3//\//--}
                [ -d "$d3" ] && echo ingnore $f3 && continue;
                echo $f3 >> "$tempFile" 
            done
        done
    done  
done

echo Scan folders in parallel
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
        echo "job $jobID $folder" 
        find "$folder" -type d >> "$tempFile.$jobID.txt" 2>> $tempFile.$jobID.err || echo "scan job $jobID error shown above" >> $tempFile.$jobID.err
        rm -r "$dFolderTmp/lock.$jobID" 
        echo removed "$dFolderTmp/lock.$jobID" for "$folder"
     ) &
done

# doest not work somehow
#wait

while true; do 

    [[ $sDir == *scratch* ]] && sleep 5 && break 

    ls "$dFolderTmp/lock.*" 2>/dev/null && sleep 30 || break 
done 

#sleep 20
cat  $tempFile.*.txt > $tempFile.txt
mkdir -p tmp 
cp $tempFile.*.txt tmp
sleep 5 
cp $tempFile.txt $folders

cat $tempFile.*.err >&2

echo "All folders found:": 
cat $folders

