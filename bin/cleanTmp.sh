#!/bin/bash

# list all pending and urnning jobs
t=`squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R" -u $USER`
echo -e "$t" | grep " R " 

echo running: `echo -e "$t" | grep " R " | wc -l` 

echo 

#t=`squeue -t PD -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R" -u $USER`
echo -e "$t" | grep PD  
echo pending: `echo -e "$t" | grep PD | wc -l`

echo "All /tmp/tmp.* will be deteled. Make sure there is no jobs running!!! Continue to clean tmp for all nodes?(yy)"

read -p "" x </dev/tty

[[ "$x" == yy ]] || exit 

# Extract node list from the medium partition, ignoring specified conditions
nodes=$(sinfo -h -p medium -N -o "%N %P %T" | grep -vE 'drain|down|allocated' | grep -v "\-h\-" | cut -d ' ' -f 1)

# Iterate through the list of nodes and perform SSH operations
for j in $nodes; do
    echo "Connecting to $j"
    ssh "$j" bash -c "'
        usage=\$(df /tmp | awk '\''NR==2 {sub(\"%\",\"\"); print \$5}'\'')
        echo \"Current usage of /tmp: \$usage%\"
        # Check if the usage is greater than 10%
        if [ \"\$usage\" -gt 10 ]; then
            echo \"Usage is above 10%. Proceeding with deletion.\"
            # Loop through files and directories to be deleted

            # echo -e \"Clean it up? (y)\"
    
            # read -p \"\" x </dev/tty
    
            [[ "$x" != y ]] && continue

            for i in {0..9} {a..z} {A..Z}; do
                echo \"Deleting /tmp/tmp.\$i*\"
                rm -rf /tmp/tmp.\$i* 2>/dev/null
            done
        else
            echo \"Usage is not above 10%. No deletion performed.\"
        fi
    '"    
done
