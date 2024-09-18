#!/bin/bash

#set -x
#set -e 

# make sure the tar file is correct and the folders are the same
function checkFolder() {
    
    local path="$1"; path="$dFolder${path#$sFolder}"; 

    diff -u <(find "$1" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort) <(find "$path" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort) | while read -r line; do
        if [[ "$line" =~ ^- && ! "$line" =~ ^--- ]]; then
            folder="${line:1}"
            echo mkdir $path/$folder
        elif [[ "$line" =~ ^\+ && ! "$line" =~ ^\+\+\+ ]]; then
            folder="${line:1}"
            echo rm -r $path/$folder
        fi
    done

    # Generate and sort the list of files in the current working directory and store in variable
    # file_list=$(find $1  -maxdepth 1 -mindepth 1 -type f -printf "%P\n" | sort)

    # if [ -z "$file_list" ]; then 
    #     echo no files  
    #     return 
    # fi 

    tarFiles=$(tar -tf $path/*.tar | sort)

    # Check if there are differences
    if [ ! -z "$(diff <(find $1  -maxdepth 1 -mindepth 1 -type f -printf "%P\n" | sort) <(echo $tarFiles))" ]; then
        
        #echo "Differences found:"
        echo rm $path/*.tar $path/*.md5sum 
        echo sudo archiveFolder 1 0 
    fi
}

[ $# -ne 2 ] && echo "Usage: $0 <sourceDir> <nProcess>" && exit 1

sFolder=`realpath $1`

dFolder=${sFolder#*datasets/}
    #dFolder=${dFolder#*1TRaw/}
dFolder=${dFolder//\//--}

checkFolder $sFolder 0


exit 

nJobs="$2"

afolders="aFolders.txt"
folders="pFolders.txt"
files="pFiles.txt"

[ -f $folders ] && echo Folder file already exist. Please delete it first: $folders && exit 1



#[ $level -lt 1 ] && echo Minimum folder level is 1. && exit 1

dFolderTmp=`mktemp -d`
tempFile=$(mktemp)
touch $tempFile.log

trap "rm -r $dFolderTmp $tempFile $tempfile.log $tempFile.txt  $tempFile.*.txt $tempFile.*.folder $tempFile.*.file 2>/dev/null" EXIT

echo $sDir > "$tempFile.0.txt"

echo "Working on first level..."

while true; do sudo -v; sleep 60; done &

sudo find "$sDir" -mindepth 1 -maxdepth 1 -type d > "$tempFile" || echo "scan level 1 error shown above"
sudo find "$sDir" -mindepth 1 -maxdepth 1 \( -type d ! -perm -g=x ! -perm -o=x \) -print >> $tempFile.0.folder
sudo find "$sDir" -mindepth 1 -maxdepth 1 \( -type f ! -perm -g=x ! -perm -o=x \) -print >> $tempFile.0.file

x=$(wc -l < "$tempFile") 

if [ "$x" -lt 5000 ]; then
    cat "$tempFile" >> $tempFile.0.txt
    echo "Working on second level..." 
    sudo find "$sDir" -mindepth 2 -maxdepth 2 -type d > "$tempFile" || echo "scan level 2 error shown above"
    sudo find "$sDir" -mindepth 2 -maxdepth 2 \( -type d ! -perm -g=x ! -perm -o=x \) -print >> $tempFile.0.folder
    sudo find "$sDir" -mindepth 2 -maxdepth 2 \( -type f ! -perm -g=r ! -perm -o=r \) -print >> $tempFile.0.file 

    x=$(wc -l < "$tempFile") 
    if [ "$x" -lt 5000 ]; then 
        cat "$tempFile" >> $tempFile.0.txt
        echo "Working on third level..." 
        sudo find "$sDir" -mindepth 3 -maxdepth 3 -type d > "$tempFile" || echo "scan level 3 error shown above"
        sudo find "$sDir" -mindepth 3 -maxdepth 3 \( -type d ! -perm -g=x ! -perm -o=x \) -print >> $tempFile.0.folder
        sudo find "$sDir" -mindepth 3 -maxdepth 3 \( -type f ! -perm -g=r ! -perm -o=r \) -print >> $tempFile.0.file 

         x=$(wc -l < "$tempFile") 
        if [ "$x" -lt 5000 ]; then 
            cat "$tempFile" >> $tempFile.0.txt
            echo "Working on fouth level..." 
            sudo find "$sDir" -mindepth 4 -maxdepth 4 -type d > "$tempFile" || echo "scan level 3 error shown above"
            sudo find "$sDir" -mindepth 4 -maxdepth 4 \( -type d ! -perm -g=x ! -perm -o=x \) -print >> $tempFile.0.folder
            sudo find "$sDir" -mindepth 4 -maxdepth 4 \( -type f ! -perm -g=r ! -perm -o=r \) -print >> $tempFile.0.file 
        fi
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
        sudo find "$folder" -type d >> "$tempFile.$jobID.txt" || echo "scan job $jobID error shown above" 
        
        sudo find "$folder" \( -type d ! -perm -g=x ! -perm -o=x \) -print >> $tempFile.$jobID.folder 
        sudo find "$folder" \( -type f ! -perm -g=r ! -perm -o=r \) -print >> $tempFile.$jobID.file 
        rm -r "$dFolderTmp/lock.$jobID" 
     ) &
done

# doest not work
#wait

while true; do 
  
    current_time=$(date +%s)
    
    file_mod_time=$(stat -c %Y $tempFile.log)

    time_diff=$((current_time - file_mod_time))

    if [ "$time_diff" -ge 12000 ]; then 
        
        #sleep 20
        echo finishing...
        cp $tempFile rootFolders.txt 
        cat  $tempFile.*.txt > $tempFile.txt
        cat  $tempFile.*.file > $tempFile.file
        cat  $tempFile.*.folder > $tempFile.folder

        cp $tempFile.txt $afolders
        cp $tempFile.folder $folders
        cp $tempFile.file $files

        echo "All folders found:": 
        head $afolders
        head $folders
        head $files

        break 
    fi 

    #sudo -v
    sleep 60
done 

sleep 5 

