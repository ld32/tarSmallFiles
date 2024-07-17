#!/bin/bash
#set -x
set -e

function tarFiles() {
    local files=${1#\\n}                           # remove leading \n

    local item=${files%%\\n*}-${files##*\\n}       # firstFile-lastFile

    [ -f "$2/$item.tar" ] && echo tar done earlier: $2/$item.tar && return
 
    echo -e "$files" > "$2/$item.list.txt"
    local tmp=`mktemp` &&
    tar --create --preserve-permissions --file "$tmp" -T $2/$item.list.txt &&
    mv "$tmp"  "$2/$item.tar" && result=`md5sum "$2/$item.tar"` && echo "${result//$pattern/}" > $2/$item.md5sum &&
    echo -e "\njob $3\n$(date)\ncd `pwd`\ntar --create --preserve-permissions --file $2/$item.tar -T $2/$item.list.txt" | tee -a $dFolder/archive.log 
}

function archiveFiles() {
    [ -f "$dFolder/log/${1//\/}.done" ] && echo echo tar done earlier for folder: $1 && return
     
    local files=""

    local totalSize=0


    local line="" 
    for line in `find -L . -maxdepth 1 -mindepth 1 -type f -printf "%f----%k\n" | sort -n`; do  # %f file name, %k file size
        local item=${line%----*}

        local size=${line#*----}

        [ "$size" -gt "1048576" ] && cp "$item" "$2" && continue # bigger than 1G, inore it

        files="$files\n$item"

        totalSize=$((totalSize + size))

        if [ "$totalSize" -gt "1048576" ]; then # bigger than 1G
            tarFiles "$files" "$1" $2
            files=""
            totalSize=0
        fi
    done
    if [ ! -z "$files" ]; then
        tarFiles "$files" "$1" $2
    fi
    touch "$dFolder/log/${1//\/}.done" 
}

function archiveFolder() {
    
    cd $1 || { echo folder not accessible, ignoer it: `pwd`/$1 && return; }

    if [[ "$action" == scan ]]; then 
        echo `pwd` | tee -a $dFolder/folders.txt
    else 
        mkdir -p "$2"
    fi 

    local line="" 
    for line in `find -L . -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | sort -n`; do
        ( archiveFolder $line "$2/$line" )
    done

    if [[ "$action" == singleNode ]]; then 
    #    echo $(pwd)
    #else
        while true; do
            local jobID=0
            if { set -C; 2>/dev/null >$dFolderTmp/lock.0; }; then
                for i in $(seq 1 $nJobs); do
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
        (archiveFiles "$2" $jobID && rm -f $dFolderTmp/lock.$jobID) &     
    fi     
}

# script is sourced, so only source the bash functions
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return  


date
echo Running: $0 $@

nJobs=$1

sFolder=`realpath $2`

dFolder=`realpath $3`

action="$4" 

usage() {
    echo "Usage: $0 <nJobs> <sourceFolder> <destinationFolder> <action: singleNode/scan/sbatch>"; exit 1;
}

[ ! -d "$sFolder" ] && echo Source folder not exist: $sFolder && usage

[[ "$action" == scan ]] || [[ "$action" == singleNode ]] || [[ "$action" == sbatch ]] || { echo action wrong: $action; usage; }

mkdir -p $dFolder/log

dFolderTmp=`mktemp -d`

trap "rm -r $dFolderTmp" EXIT

startTime=`date`

pattern="/[^ ]*/"
if [[ "$action" == sbatch ]]; then 
    [ -f $dFolder/folders.txt ] || $(dirname $0)/tar.sh 2 $sFolder $dFolder scan
    x=$(wc -l < $dFolder/folders.txt)  
    rows_per_job=$(( x / $nJobs ))
    echo "#!/bin/bash" > $dFolder/array.sh 
    echo "#SBATCH --array=1-$nJobs" >> $dFolder/array.sh 
    echo "#SBATCH --output=slurm_%A_%a.out" >> $dFolder/array.sh  
    echo "#SBATCH --error=slurm_%A_%a.out" >> $dFolder/array.sh  
    echo >> $dFolder/array.sh
    echo "set -e" >> $dFolder/array.sh 
    echo "echo job index: \$SLURM_ARRAY_TASK_ID" >> $dFolder/array.sh 
    echo dFolder=$dFolder >> $dFolder/array.sh
    echo "start_row=\$(( (SLURM_ARRAY_TASK_ID - 1) * $rows_per_job + 1 ))" >> $dFolder/array.sh 
    echo "end_row=\$(( SLURM_ARRAY_TASK_ID * $rows_per_job ))"  >> $dFolder/array.sh 
    echo "[ \$SLURM_ARRAY_TASK_ID -eq $nJobs ] && end_row=$x"  >> $dFolder/array.sh 
    echo "sed -n \"\${start_row},\${end_row}p\" $dFolder/folders.txt " >> $dFolder/array.sh
    echo "source $0" >> $dFolder/array.sh
    echo "sed -n \"\${start_row},\${end_row}p\" $dFolder/folders.txt  | while IFS= read -r line; do" >> $dFolder/array.sh 
    echo "  cd \$line" >> $dFolder/array.sh
    echo "  mkdir -p $dFolder\${line#$sFolder}" >> $dFolder/array.sh
        
    echo "  archiveFiles $dFolder\${line#$sFolder} \$SLURM_ARRAY_TASK_ID" >> $dFolder/array.sh 
    #echo "  exit" >> $dFolder/array.sh
    echo done >> $dFolder/array.sh 
    echo echo done >> $dFolder/array.sh 
    cat $dFolder/array.sh
    
    #export SLURM_ARRAY_TASK_ID=1
    #sh $dFolder/array.sh
    [[ "$SLURM_CLUSTER_NAME" = o2-dev ]] && acc="-A rccg"
    sbatch $acc -t 2:0:0 -p short --ntasks-per-node=1 --spread-job --mem 10G $dFolder/array.sh
else        
    pids=()         
    archiveFolder "$sFolder" "$dFolder"
    wait
    endTime=`date`
    echo "Time used: $((($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s'))/60)) minutes" | tee -a $dFolder/archive.log
fi 
