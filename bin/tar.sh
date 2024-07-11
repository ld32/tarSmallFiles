#!/bin/bash
#set -x
set -e

#I think you can run tests on /n/groups/htem/tier2/cb3 (but please don't actually archive it); /n/groups/htem/tier2/cb3/sections/170218121547_cb3_0293 is just one section out of ~500, and our more recent datasets are about 1000-4000 sections long. Actually the datasets in /n/groups/htem/tier2 are the ones we prepared to go on tier2 but did not happen because of IT difficulties so they could also make good case studies.

function tarFiles() {
    local files=${1#\\n}                           # remove leading \n

    local item=${files%%\\n*}-${files##*\\n}       # firstFile-lastFile

    [ -f "$2/$item.tar" ] && echo done earlier && return
 
    echo -e "$files" > "$2/$item.list.txt"
    local tmp=`mktemp` &&
    tar --create --preserve-permissions --file "$tmp" -T $2/$item.list.txt &&
    mv "$tmp"  "$2/$item.tar" && result=`md5sum "$2/$item.tar"` && echo "${result//$pattern/}" > $2/$item.md5sum &&
    echo $(date) | tee -a  $dFolder/archive.log  &&
    echo cd `pwd` >> $dFolder/archive.log  &&
    echo tar --create --preserve-permissions --file "$2/$item.tar" -T $2/$item.list.txt | tee -a $dFolder/archive.log 
}

function archiveFiles() {
    local files=""

    local totalSize="0"

    for line in `find -L . -maxdepth 1 -mindepth 1 -type f -printf "%f----%k\n" | sort -n`; do  # %f file name, %k file size
        local item=${line%----*}

        local size=${line#*-----}

        [ "$size" -gt "1048576" ] && cp "$item" "$2" && continue # bigger than 1G, inore it

        files="$files\n$item"

        totalSize=$((totalSize + size))

        if [ "$totalSize" -gt "1048576" ]; then # bigger than 1G
            (tarFiles "$files" "$1")
            files=""
            totalSize="0"
        fi
    done
    if [ ! -z "$files" ]; then
        (tarFiles "$files" "$1")
    fi
}


function archiveFolder() {
    mkdir -p "$2"

    cd $1

    for line in `find -L . -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | sort -n`; do
        (archiveFolder $line "$2/$line")
    done

     while true; do
         local jobID=0
         if { set -C; 2>/dev/null >$dFolderTmp/lock.0; }; then
            for i in $(seq 1 $core); do
                if [ ! -f $dFolderTmp/lock.$i ]; then
                    touch $dFolderTmp/lock.$i
                    jobID=$i  
                    break
                fi
            done
            rm -f $dFolderTmp/lock.0
        fi
        [ "$jobID" -eq "0" ] && sleep 0.01 || break

    done
    echo job $jobID 
    (archiveFiles "$2" && rm -f $dFolderTmp/lock.$jobID  ) &  
}

sFolder="$2"

dFolder="$3"

core=$1

[ -d "$sFolder" ] || { echo "Usage: $0 <cores> <sourceFolder> [destinationFolder]"; exit 1; }

[ -z "$dFolder" ] && dFolder="$sFolder-tar"

[ -d "$dFolder" ] || mkdir -p $dFolder

dFolder=`realpath $dFolder`

dFolderTmp=`mktemp -d`

trap "rm -r $dFolderTmp" EXIT

startTime=`date`

pattern="/[^ ]*/"

archiveFolder "$sFolder" "$dFolder"

wait

endTime=`date`

echo "Time used: $(($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s')))" >> $dFolder/archive.log
