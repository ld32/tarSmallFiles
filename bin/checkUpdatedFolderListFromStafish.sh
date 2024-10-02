#!/bin/bash

#set -x
set -e

function checkArchive() {
    
    echo working on "$1"
    
    local path="$2"; local tmpfile=$(mktemp)

    #echo working on $1 and $path
    # check folders
    local sFolders=$(find "$1" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2> $tmpfile | sort)
    echo -e "$sFolders"
    [ -s $tmpfile ] && echo -e "Error: ----------`cat $tmpfile`---------------" && rm $tmpfile  && return 
    rm $tmpfile
    #[[ "$?" == 0 ]] || return
     
    local dFolders=$(find "$path" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)

    diff -u <(echo -e "$sFolders") <(echo -e "$dFolders") | while read -r line; do
        #echo $line 
        if [[ "$line" =~ ^- && ! "$line" =~ ^--- ]]; then
           
            echo checking folder $1 vs $path
            echo Error: missing folder: $path/${line:1}
        
            echo
        elif [[ "$line" =~ ^\+ && ! "$line" =~ ^\+\+\+ ]]; then
           
            echo checking folder $1 and $path
            echo Error: extra folder: $path/${line:1}

            echo 
        fi
    done
    
    #local tarFiles=$(tar -tf "$path/*.tar" 2>/dev/null | sort)
    local tarFiles=$(find "$path" -maxdepth 1 -mindepth 1 -name "*.tar" -print0 2>/dev/null | xargs -0 tar -tf 2>/dev/null | sort)
    
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
        echo "$1" >> $logDir/foldersPass.$3.txt  
    fi
}

[ ! -f "$1" ] && echo Folder list not found && exti

sFolder=$1

dFolder=${1#*datasets/}
tmp=${dFolder%%/*}
if [ -d "$tmp" ]; then 
    dFolder=`realpath $tmp` 
else 
    tmp1=${dFolder#$tmp/}
    tmp1=${tmp1%%/*}
    if [ -d "$tmp--$tmp1" ]; then 
        dFolder=`realpath $tmp--$tmp1`
    else 
        tmp2=${dFolder#$tmp/$tmp1}
        tmp2=${tmp2%%/*}
        if [ -d "$tmp--$tmp1--$tmp2" ]; then 
            dFolder=`realpath $tmp--$tmp1--$tmp2`
        else 
            tmp3=${dFolder#$tmp/$tmp1/$tmp2/}
            tmp3=${tmp3%%/*}
            if [ -d "$tmp--$tmp1--$tmp2--$tmp3" ]; then 
                dFolder=`realpath $tmp--$tmp1--$tmp2--$tmp3`
            else 
                dFolder=`realpath smallFolders`
            fi 
        fi 
    fi 
fi 

for folder in `cat $1`; do 
    checkArchive $folder $dFolder 
done 

echo done 