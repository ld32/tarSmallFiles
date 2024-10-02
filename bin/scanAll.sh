for i in `cat allDFolders.txt`; do
    sDir=$i
    dDir=${sDir#*datasets/}

    echo $i

    dDir=${dDir//\//--}

    [ -f ${dDir}Log/folders.txt ] || echo no

    
    [ -d  ${dDir}Log ] && continue

    #echo -e "Submit job?(y)"
        
    #read -p "" x </dev/tty
    
        
    #[[ "$x" == y ]] || continue

    if [[ "$sDir" == *datasets ]]; then 
        dDir=smallFolders
        mkdir  ${dDir}Log && sbatch -A rccg --qos=testbump -o ${dDir}Log/$dDir.scan.log -J scan.$dDir -t 72:0:0 -p medium --mem 4G -c 2  --wrap="scanSmallFolders.sh $i 5"; 
        sleep 3600
    else 
        mkdir  ${dDir}Log && sbatch -A rccg --qos=testbump -o ${dDir}Log/$dDir.scan.log -J scan.$dDir -t 72:0:0 -p medium --mem 4G -c 2  --wrap="scanFolders.sh $i 5"; 
        sleep 3600
    fi 
done 

