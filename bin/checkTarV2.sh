#!/bin/bash

#set -x
#set -e

function checkArchive() {
    
    echo working on "$1"

   
    # if [ "$(stat -c %Y "$1")" -gt "$(stat -c %Y "$2")" ]; then
    #     echo "Error: data updated: $1 is newer than $2."
    # fi
    # return; 
    
    local path="$2"; local tmpfile=$(mktemp)

    #echo working on $1 and $path
    # check folders
    # local sFolders=$(find "$1" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2> $tmpfile | sort)
    # echo -e "$sFolders"

    # [ -s $tmpfile ] && echo -e "Error: ----------`cat $tmpfile`---------------" && rm $tmpfile  && return 
    
    # rm $tmpfile
    # #[[ "$?" == 0 ]] || return
     
    # # Using command grouping to ignore errors
    # local dFolders=$({ find "$path" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null || true; } | sort)

    # local folderMatch="y"

    # while read -r line; do
    #     if [[ "$line" == "-" || "$line" == "+" ]]; then 
    #         echo 
    #     elif [[ "$line" =~ ^- && ! "$line" =~ ^--- ]]; then
    #         echo checking folder $1 vs $path
    #         echo Error: missing folder: $path/${line:1}, please work on: $1/${line:1}
    #         echo
    #     elif [[ "$line" =~ ^\+ && ! "$line" =~ ^\+\+\+ ]]; then
    #         echo checking folder $1 and $path
    #         echo Error: extra folder: $path/${line:1}
    #         echo 
    #     fi
    #     folderMatch=""
    # done < <(diff -u <(echo -e "$sFolders") <(echo -e "$dFolders"))

    
    #local tarFiles=$(tar -tf "$path/*.tar" 2>/dev/null | sort)
    local tars=$(find "$path" -maxdepth 1 -mindepth 1 -name "*.tar" | sort)
    local count=$(echo -e "$tars" | wc -l)

    [ "$count" -eq 0 ] && echo -e "Error: missing tars: for $i and $path"
    
    [ "$count" -gt 1 ] && echo -e "Error: multiple tars: $tars for $i and $path" && tars=$(echo -e "$tars" | head -n 1)

    #local tarFiles=$(find "$path" -maxdepth 1 -mindepth 1 -name "*.tar" ! -name ".*" -print0 | head -zn 1 2>/dev/null | xargs -0 tar -tf 2>/dev/null | sort)
    return 
    local tarFiles=$(tar -tf "$tars" 2>/dev/null | sed 's|^\./||' | sort)

    local oFiles=$(find "$1"  -maxdepth 1 -mindepth 1 \( -type f -o -type l \) -printf "%P\n" 2> $tmpfile | sort )
    [ -s $tmpfile ] && echo -e "Error: ----------`cat $tmpfile`---------------" && rm $tmpfile  && return 
    rm $tmpfile

    # Check files to see if there are differences
    if [ -n "$tarFiles$oFiles" ] && [ -n "$(diff <(echo -e "$oFiles") <(echo -e "$tarFiles"))" ]; then
        echo checking file $1 vs $path
        ls $path/*.tar 2>/dev/null && echo Error: wrong tar to delete: $path/*.tar $path/*.md5sum 
        if [ -n "$tarFiles" ]; then 
            echo files in tar: $tarFiles    
        else 
            echo No files were found in tar.   
        fi 
        [ -n "$oFiles" ] &&  echo orignal files: $oFiles 
        echo Error: need rerun: archiveFolder $1 0 
        echo
    else 
    #     echo chmod/own for folders 
    #     # work on folders 
    #     local folders1
    #     local folders2
    #     mapfile -t folders1 <<< "$sFolders"
    #     mapfile -t folders2 <<< "$dFolders"

    #     for i in "${!folders1[@]}"; do
    #         [ -d "$path/${folders2[$i]}" ] || continue 
    #         chmod "$(stat -c %a "$1/${folders1[$i]}")" "$path/${folders2[$i]}"
    #         local user=`ls -ld "$1/${folders1[$i]}" | awk '{print $3}'`
    #         [[ "$user" =~ ^[0-9]+$ ]] && user=wal5
    
    #         #local user=$(stat -c %U "$1/${folders1[$i]}")
    #         chown "$user:htem" "$path/${folders2[$i]}"
    #     done
    
    #    echo chmod/own for files 
        
    #     if [ ! -z "$tarFiles" ]; then 
    #         echo "$tarFiles"
    #         local owner=`ls -ld "$1" | awk '{print $3}'`
    #         [[ "$owner" =~ ^[0-9]+$ ]] && owner=wal5
    #         #local owner=$(stat -c '%U' "$1")
    #         chmod g+rw "$path/*.tar" "$path/*.md5sum" || true 
    #         chown $owner:htem $path "$path/*.tar" "$path/*.md5sum" || true
    #     fi 
       [ -z "$folderMatch" ] &&  echo "$1" >> $logDir/foldersPass.$3.txt  || return 
    fi
}

# script is sourced, so only source the bash functions
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return  

usage() {
    echo "Usage: $0 <sourceFolder>"; exit 1;
}

date
#echo Running $0 $@ 

#set -x  

sFolder=`realpath $1`

#if [ -z $4 ]; then 
    dFolder=${sFolder#*datasets/}

    [[ "$dFolder" == *datasets ]] && dFolder=smallFolders 

    #dFolder=${dFolder#*1TRaw/}
    dFolder=${dFolder//\//--}

    [ -f $dFolder.log ] && mv $dFolder.log $dFolder.log.$(stat -c '%.19z' $dFolder.log | cut -c 6- | tr " " . | tr ":" "-")

    dFolder=`realpath $dFolder`    
    #action="$3" 
#else 
#     dFolder=`realpath $3`
#    action=$4
#fi

[ ! -d "$sFolder" ] && echo Source folder not exist: $sFolder && usage

logDir=${dFolder}Log

mkdir -p $dFolder $logDir

touch $logDir/archive.log

startTime=`date`

date >> $logDir/readme
echo $USER >> $logDir/readme
echo $0 $sFolder | tee -a $logDir/readme
echo $SLURM_JOB_ID
    if [ ! -f $logDir/folders.txt ]; then 
        echo Folder scan is not done yet
        exit 1
    fi 

    #exit; 

    notDone=''
    if [ -f $logDir/allJobs.txt ]; then 
        IFS=$'\n'; out=`squeue -u $USER -t PD,R -o "%.18i"`
        if [ ! -z "$out" ]; then 
            for line in `cat $logDir/allJobs.txt`; do
                [[ "$out" == *$line* ]] && notDone="$line $notDone"
            done 
        fi     
    fi 

    [ -z "$notDone" ] || { echo -e "A run was started earlier on the folder and the folowing jobs are still pending or running\nPlease wait for them to finish or cancel them:\n$notDone"; exit 1; }

    # if this is a rerun, use old nJobs
    # if [ -f $logDir/runTime.txt ]; then 
    #     x=`grep "^nJobs " $logDir/runTime.txt | tail -n1`
    #     x=${x#* }; 
    #     [ ! -z "$x" ] && nJobs=$x || echo nJobs $nJobs >> $logDir/runTime.txt
    #     cp $logDir/runTime.txt $logDir/runTime.txt.back
    # else 
    #     echo nJobs $nJobs >> $logDir/runTime.txt
    # fi

    rm -r $logDir/exclusive $logDir/allJobs.txt  2>/dev/null || true 

#    [ -f $logDir/runTime.txt ] && cp $logDir/runTime.txt $logDir/runTime.txt.back

    x=$(wc -l < $logDir/folders.txt)  

    rows_per_job=10000
    nJobs=$(( (x + rows_per_job - 1) / rows_per_job ))

    # x=$(wc -l < $logDir/folders.txt)  
    # [ $x -lt $nJobs ] && nJobs=$x
    #echo nJobs $nJobs >> $logDir/runTime.txt

    nodeFile=$logDir/sbtachExclusivceLog.txt

    #nodeFile=/n/data3_vast/data3_datasets/ld32/sbatachExclusivceLog.txt
    
    [[ "`realpath .`" == "/n/scratch/users/l/ld32/debug"* ]] && nodeFile=/n/scratch/users/l/ld32/debug/sbatachExclusivceLog.txt

    sinfo -p short -N -o "%N %P %T" | grep -v drain | grep -v down | grep -v allocated | grep -v "\-h\-" | cut -d ' ' -f 1,2 > $nodeFile
    
    #[[ "$PWD" == "/n/scratch/users/l/ld32/debug"* ]] && nodeFile=/n/scratch/users/l/ld32/debug/sbatachExclusivceLog.txt

    #rows_per_job=$(( x / $nJobs ))

     [ -f $logDir/job.sh  ] && mv $logDir/job.sh  $logDir/job.sh.$(stat -c '%.19z' $logDir/job.sh | cut -c 6- | tr " " . | tr ":" "-")

    
    echo "#!/bin/bash" > $logDir/job.sh   
    echo >> $logDir/job.sh
    #echo "set -e" >> $logDir/job.sh 

    echo "jIndex=\$1" >> $logDir/job.sh
    echo "echo job index: \$jIndex" >> $logDir/job.sh
    echo "echo \$jIndex start time \$(date) \$SLURM_JOBID" >> $logDir/job.sh

    echo "export sFolder=$sFolder" >> $logDir/job.sh
    echo "export dFolder=$dFolder" >> $logDir/job.sh
    echo "export logDir=$logDir" >> $logDir/job.sh
    
    echo "trap \"rm -r \$logDir/exclusive 2>/dev/null; echo exiting and delete lock; \" EXIT" >> $logDir/job.sh

    echo "declare -A file_lines" >> $logDir/job.sh

    #echo "[ -f \$logDir/foldersPass.\$jIndex.txt ] && rm \$logDir/foldersPass.\$jIndex.txt" >> $logDir/job.sh
  
    #echo "for file in \`ls \$logDir/foldersPass.\$jIndex.txt 2>/dev/null\`; do" >> $logDir/job.sh

    echo "for file in \`ls \$logDir/foldersPass.*.txt 2>/dev/null\`; do" >> $logDir/job.sh
    echo "    while IFS= read -r line; do" >> $logDir/job.sh
    echo "        line=\${line#*datasets/}" >> $logDir/job.sh 
    echo "        file_lines[\"\$line\"]=1" >> $logDir/job.sh
    echo "    done < \"\$file\"" >> $logDir/job.sh
    echo "done" >> $logDir/job.sh
    echo "" >> $logDir/job.sh

    echo "start_row=\$(( (jIndex - 1) * $rows_per_job + 1 ))" >> $logDir/job.sh 
    echo "end_row=\$(( jIndex * $rows_per_job ))"  >> $logDir/job.sh 
    echo "[ \$jIndex -eq $nJobs ] && end_row=$x"  >> $logDir/job.sh 
    echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt " >> $logDir/job.sh
    echo "source $0" >> $logDir/job.sh

    echo "sed -n \"\${start_row},\${end_row}p\" $logDir/folders.txt  | while IFS= read -r line; do" >> $logDir/job.sh         
    echo "  if [[ -n \"\${file_lines[\"\${line#*datasets/}\"]}\" ]]; then" >> $logDir/job.sh
    echo "    echo \"passed: \$line\"" >> $logDir/job.sh
    echo "  else" >> $logDir/job.sh
    echo "    checkArchive \"\$line\" \"\$dFolder\${line#\$sFolder}\" \$jIndex" >> $logDir/job.sh 
    echo "  fi" >> $logDir/job.sh
    echo done >> $logDir/job.sh 
    echo echo done >> $logDir/job.sh
    
    echo "echo \$jIndex end time \$(date) \$SLURM_JOBID" >> $logDir/job.sh 
    
    #echo "if [ -f $logDir/tarError\$jIndex.txt ]; then" >> $logDir/job.sh 
    #echo "  er=\`cat $logDir/tarError\$jIndex.txt\`" >> $logDir/job.sh
    #echo "  echo -e \"Subject: !!! With error: s\$jIndex/\$SLURM_JOBID done ${dFolder##*/}\nPlase check: \$er\" | sendmail `head -n 1 ~/.forward` " >> $logDir/job.sh
    #echo "else" >> $logDir/job.sh 
    
    
    #echo "  echo -e \"Subject: s\$jIndex/\$SLURM_JOBID done ${dFolder##*/}\" | sendmail `head -n 1 ~/.forward` " >> $logDir/job.sh
    
    
    #echo "fi" >> $logDir/job.sh 
    # remove later
    #echo "sleep 35" >> $logDir/job.sh 

    echo "while ! mkdir $logDir/exclusive 2>/dev/null; do" >> $logDir/job.sh 
    #echo "  echo waiting for the lock" >>  $logDir/job.sh 
    echo "  sleep \$((1 + RANDOM % 10))" >> $logDir/job.sh 
    echo "done" >> $logDir/job.sh 

    echo "echo got the lock" >>  $logDir/job.sh 

    #echo "echo job $jIndex original sbtachExclusivceLog.txt: >&2" >> $logDir/job.sh
    #echo "cat $nodeFile >&2" >> $logDir/job.sh 

    echo "sed -i \"s/^o\${SLURM_JOB_NODELIST}/\${SLURM_JOB_NODELIST}/\" $nodeFile" >> $logDir/job.sh 
    echo "sed -i \"s/spaceHolder\${SLURM_JOB_ID}/; done \$(date '+%m-%d %H:%M:%S')/\" $nodeFile" >> $logDir/job.sh  

    # release holding job
    echo "IFS=$'\n'" >> $logDir/job.sh 
    echo "for line in \`grep '^hold' $nodeFile | grep -v unhold\`; do " >> $logDir/job.sh 
    echo "  job=\${line##* }; p=\`echo \$line | cut -d' ' -f2\`" >> $logDir/job.sh 
    echo "  node=\`grep '^com' $nodeFile | grep \$p | shuf -n 1 | tr -s \" \" | cut -f1 | cut -d' ' -f1\`" >> $logDir/job.sh 
    echo "  if [ -z \"\$node\" ]; then " >> $logDir/job.sh 
    echo "      break" >> $logDir/job.sh 
    echo "  else " >> $logDir/job.sh 
    echo "      scontrol update JobID=\$job NodeList=\$node" >> $logDir/job.sh 
    echo "      scontrol release JobID=\$job" >> $logDir/job.sh 
    echo "      sed -i \"s/^\${node}/o\${node}/\" $nodeFile" >> $logDir/job.sh 
    echo "      sed -i \"s/\${job}/\${job}; unhold onto: \$node by job: \${SLURM_JOB_ID} \$(date '+%m-%d %H:%M:%S')spaceHolder\${job}/\" $nodeFile" >> $logDir/job.sh  
    echo "  fi " >> $logDir/job.sh 
    #echo "  echo job $jIndex updated sbtachExclusivceLog.txt: >&2" >> $logDir/job.sh 
    #echo "  cat $nodeFile >&2" >> $logDir/job.sh 
    echo "done " >> $logDir/job.sh 

    # switch nodes for jobs penidng more than x seconds
    echo "pending=\`squeue -u $USER -t PD -o \"%.18i\"\`" >> $logDir/job.sh 
    echo "if [ ! -z \"\$pending\" ]; then" >> $logDir/job.sh  
    echo "  for line in \`grep spaceHolder $nodeFile\`; do " >> $logDir/job.sh 
    echo "      job=\${line##*spaceHolder}; p=\`echo \$line | cut -d' ' -f2\`" >> $logDir/job.sh 
     
    # submit short 08-07 14:34:37 job: 43540546 on: compute-a-16-35spaceHolder43540546
    echo "      t=\${line##submit short }; t=\${t% job*}; t=\$(date -d \"\$t\" +%s)" >> $logDir/job.sh 
    echo "      ct=\$(date +%s); pt=\$((ct - t)); jIndex=\${line#*job }; jIndex=\${jIndex%%:*}" >> $logDir/job.sh 
    
                # pending for more than x seconds
    echo "      if [ \"\$pt\" -gt 1200 ] && [[ "\$pending" == *\$job* ]]; then" >> $logDir/job.sh 
    echo "          node=\`grep '^com' $nodeFile | grep \$p | shuf -n 1 | tr -s \" \" | cut -f1 | cut -d' ' -f1\`" >> $logDir/job.sh 
    echo "          if [ -z \"\$node\" ]; then " >> $logDir/job.sh 
    echo "              break" >> $logDir/job.sh 
    echo "          else " >> $logDir/job.sh 
    echo "              scancel \$job" >> $logDir/job.sh
    echo "              cmd=\"sbatch -A rccg --qos=testbump -w \$node -o $logDir/slurm.\$jIndex.1.txt -J ${dFolder##*/}.\$jIndex.1 -t 12:0:0 -p short --mem 2G $logDir/job.sh \$jIndex\" " >> $logDir/job.sh 
    echo "              output=\"\$(eval \$cmd)\" " >> $logDir/job.sh 
    echo "              sed -i \"s/^\${node}/o\${node}/\" $nodeFile " >> $logDir/job.sh 
    echo "              echo submit short \`date '+%Y-%m-%d %H:%M:%S'\` job \$jIndex: \${output##* } on: \${node}spaceHolder\${output##* } >> $nodeFile" >> $logDir/job.sh 
    echo "              echo \${output##* } >> $logDir/allJobs.txt" >> $logDir/job.sh 
    echo "              echo submitted \${output##* }/\$jIndex on \$node >> $logDir/runTime.txt" >> $logDir/job.sh 

    echo "              echo resumit to switch node for \$job to \$node" >> $logDir/job.sh 
    #echo "             scontrol update JobID=\$job NodeList=\$node" >> $logDir/job.sh 
    #echo "             scontrol release JobID=\$job" >> $logDir/job.sh 
    echo "              sed -i \"s/^\${node}/o\${node}/\" $nodeFile" >> $logDir/job.sh # don't release it because job pending forever!!
    echo "              sed -i \"s/spaceHolder\${job}/\${job}, pended too long, resumit as \${output##* } on: \$node by job: \${SLURM_JOB_ID}/\" $nodeFile" >> $logDir/job.sh  
    echo "          fi" >> $logDir/job.sh
    echo "      fi" >> $logDir/job.sh 
    #echo "      echo job $jIndex updated sbtachExclusivceLog.txt: >&2" >> $logDir/job.sh 
    #echo "      cat $nodeFile >&2" >> $logDir/job.sh 
    echo "  done " >> $logDir/job.sh 
    echo "fi" >> $logDir/job.sh

    echo "rm -r $logDir/exclusive " >> $logDir/job.sh 
    
    echo "echo released the lock" >>  $logDir/job.sh 

    echo sleep 10 >> $logDir/job.sh # wait for email to send out
    
    #echo "[ -f $logDir/tarError\$jIndex.txt ] && exit 1" >> $logDir/job.sh 
    
    echo Slurm script:
    echo Slurm script ready: $logDir/job.sh
    
    for i in `seq 1 $nJobs`; do 

        # if done earler, skip it
        [ -f $logDir/slurm.$i.txt ] && grep "^$i end time" $logDir/slurm.$i.txt && echo Done earlier && continue 
        [ -f $logDir/slurm.$i.1.txt ] && grep "^$i end time" $logDir/slurm.$i.1.txt && echo Done earlier && continue
        
        node=`grep '^com' $nodeFile | grep short | shuf -n 1 | tr -s " " | cut -f1 | cut -d' ' -f1`
        
        #node=compute-a-16-21

        if [ -z "$node" ]; then                                                             # -H
            cmd="sbatch -A rccg --qos=testbump -o $logDir/slurm.$i.txt -J ${dFolder##*/}.$i -t 12:0:0 -p short --mem 2G $logDir/job.sh $i" 
            echo Submitting job:
            echo $cmd | tee -a $logDir/readme
            output="$(eval $cmd)"
            echo $output
            #echo holdit short `date '+%m-%d %H:%M:%S'` job $i: ${output##* } >> $nodeFile
            echo ${output##* } >> $logDir/allJobs.txt
            echo submitted ${output##* }/$i >> $logDir/runTime.txt
        else          # -w $node 
            cmd="sbatch --qos=testbump -c 1 -A rccg -o $logDir/slurm.$i.txt -J ${dFolder##*/}.$i -t 12:0:0 -p short --mem 2G $logDir/job.sh $i" 
            echo Submitting job:
            echo $cmd | tee -a $logDir/readme
            output="$(eval $cmd)"
            echo $output
            sed -i "s/^${node}/o${node}/" $nodeFile
            #echo submit short `date '+%Y-%m-%d %H:%M:%S'` job $i: ${output##* } on: ${node}spaceHolder${output##* } >> $nodeFile
            echo ${output##* } >> $logDir/allJobs.txt
            echo submitted ${output##* }/$i on $node >> $logDir/runTime.txt
        fi
        
        sleep 0.5
        
    done
    cat $nodeFile >&2

    endTime=`date`
    echo "Time used: $((($(date -d "$endTime" '+%s') - $(date -d "$startTime" '+%s'))/60)) minutes" | tee -a $logDir/archive.log

    # if [ -f $logDir/checkError.txt ]; then 
    #     echo Sending scan fail email...
    #     echo -e "Subject: !!! checkTar error: $dFolder\nPlease check: $logDir/checkError.txt\n`cat $logDir/checkError.txt`" | sendmail `head -n 1 ~/.forward`
    #     exit 1 
    # fi
#else 
#    echo action wrong: $action; usage;
#fi
