#!/bin/bash

#set -x

set -e

function checkArchive() {
    
    local path="$1"; path="$dFolder${path#$sFolder}"; 
    

    #echo working on $1 and $path
    # check folders
    diff -u <(find "$1" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort) <(find "$path" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort) | while read -r line; do

        echo $line 
        if [[ "$line" =~ ^- && ! "$line" =~ ^--- ]]; then
           
            echo checking folder $1 vs $path
            echo missing folder: $path/${line:1}
            echo need rerun: archiveFolder $1 0 
            echo
        elif [[ "$line" =~ ^\+ && ! "$line" =~ ^\+\+\+ ]]; then
           
            echo checking folder $1 and $path
            echo extra folder: $path/${line:1}
            echo 
        fi
    done
    
    tarFiles=$(tar -tf $path/*.tar 2>/dev/null | sort)

    # Check files to see if there are differences
    if [ ! -z "$(diff <(find $1  -maxdepth 1 -mindepth 1 -type f -printf "%P\n" | sort) <(echo -e "$tarFiles"))" ]; then
        echo checking file $1 vs $path
        #echo "Differences found:"
        ls $path/*.tar 2>/dev/null &&  echo wrong tar to delete: $path/*.tar $path/*.md5sum 
        echo need rerun: archiveFolder $1 0 
        echo
    fi

    chmod g+rw $PATH/*.tar $PATH/*.md5sum || true 
    owner=$(stat -c '%U' "$1")
    chown $owner:htem $PATH $PATH/*.tar $PATH/*.md5sum || true 
}

export sFolder=/n/scratch/users/l/ld32/datasets/intersection/catmaided/1TRaw/small
export dFolder=/n/scratch/users/l/ld32/debug/intersection--catmaided--1TRaw--small
export logDir=/n/scratch/users/l/ld32/debug/intersection--catmaided--1TRaw--smallLog
jIndex=$1
echo job index: $jIndex
echo $jIndex start time $(date) $SLURM_JOBID >> /n/scratch/users/l/ld32/debug/intersection--catmaided--1TRaw--smallLog/runTime.txt
start_row=$(( (jIndex - 1) * 10 + 1 ))
end_row=$(( jIndex * 10 ))
[ $jIndex -eq 1 ] && end_row=10
sed -n "${start_row},${end_row}p" /n/scratch/users/l/ld32/debug/intersection--catmaided--1TRaw--smallLog/folders.txt
#source /home/ld32/data/tarSmallFiles1/bin/checkTarT.sh
sed -n "${start_row},${end_row}p" /n/scratch/users/l/ld32/debug/intersection--catmaided--1TRaw--smallLog/folders.txt  | while IFS= read -r line; do
  checkArchive "$line" $jIndex
  #exit
done
echo done