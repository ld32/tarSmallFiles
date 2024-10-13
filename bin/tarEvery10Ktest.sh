#!/bin/bash

#!/bin/bash


#SBATCH -p long
#SBATCH -t 14-00:00:00
#SBATCH --mem 5G
#SBATCH -c 1
#SBATCH --qos=testbump 
#SBATCH -J 10kfile
#set -x
#set -e

set -x

#set -e
function tarFiles() {
    local files="${1%\\n}"                        # remove leading \n

    local item="${files%%\\n*}-${files##*\\n}"       # firstFile-lastFile

    [ -f "$2/$item.tar" ] && echo Tar done earlier: $2/$item.tar && return
    
    pattern="/[^ ]*/"
    
    local tmp=$(mktemp $dFolderTmp/tmp.XXXXXX) && echo -e "$files" > $tmp.list
    tar --create --preserve-permissions --file "$tmp" -T $tmp.list &&
    mv "$tmp"  "$2/$item.tar" && result=`md5sum "$2/$item.tar"` && echo "${result//$pattern/}" > $2/$item.md5sum && rm $tmp.list &&
    echo -e "\njob $3\n$(date)\ncd `pwd`\ntar --create --preserve-permissions --file $2/$item.tar -T $tmp.list" | tee -a $logDir/archive.log
}

function archiveFolder() {

    echo working on $1
    
    local path="$1"; path="$dFolder${path#$sFolder}"; 

    #rm "$path"/*.tar "$path"/*.md5sum 2>/dev/null || true 

    #ls "$path"/*.tar >/dev/null 2>&1 && echo Tar done earlier && return


   # rm "$path"/*.tar "$path"/*.md5sum 2>/dev/null || true 
     
    mkdir -p "$path" || { echo Error: make folder $path | tee -a  $logDir/tarError$2.txt; }

    cd "$1" || { echo Error: cd folder failed $1 | tee -a  $logDir/tarError$2.txt; return; } 

   local files=""
    local line="" 
    local count=0; 
    while IFS= read -r line; do
        count=$((count+1))
        files="${files}${line}\n"
        if [ "$count" -eq 10000 ]; then 
            tarFiles "$files" "$path" "$2"
            files=""
            count=0
        fi
    done < <(find . -maxdepth 1 -mindepth 1 \( -type f -o -type l \) -printf "%f\n" | sort -n)

    if [ ! -z "$files" ]; then
        tarFiles "$files" $path $2
    fi
}

export sFolder=/n/data3/.snapshot/o2_data3_daily_2024-10-07_00-00/hms/neurobio/htem/temcagt/datasets/cb3/zarr/cb3.n5/volumes/raw_mipmap/s1/1102/735
export dFolder=/n/data3_vast/data3_datasets/ld32/test
export logDir=/n/data3_vast/data3_datasets/ld32/test
export dFolderTmp=$(mktemp -d /n/scratch/users/l/ld32/tmp.XXXXXX)
trap "rm -r $dFolderTmp $logDir/exclusive 2>/dev/null; echo exiting and delete lock; df /tmp;" EXIT

archiveFolder /n/data3/.snapshot/o2_data3_daily_2024-10-07_00-00/hms/neurobio/htem/temcagt/datasets/cb3/zarr/cb3.n5/volumes/raw_mipmap/s1/1102/735 0