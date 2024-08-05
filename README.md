# tar Small Files
To decrease number of small file, keep the folder structure, tar all files less than 1G

git clone https://github.com/ld32/tarSmallFiles.git

export PATH=$PWD/tarSmallFiles/bin:$PATH

## To tar:

### Single node job
sbatch -p short -t 12:0:0 -o slurm.singleNode.log -J singleNode --mem 20G --mail-type=all -c 10 --wrap="tar.sh 10 \<sourceFolder\> \<destinationFolder\> singleNode

For example: 

sbatch -p short -t 12:0:0 -o slurm.singleNode.log -J singleNode --mem 20G --mail-type=all -c 10 --wrap="tar.sh 10 /n/scratch/users/l/ld32/1TRaw/small smallSingleNodeTar singleNode

### Job array of 10 jobs
sbatch -p short -t 4:0:0 -o slurm.sbatch.log -J jobArray --mem 4G --mail-type=all -c 1 --wrap="tar.sh 10 \<sourceFolder\> \<destinationFolder\> sbatch

For example: 
sbatch -p short -t 4:0:0 -o slurm.sbatch.log -J jobArray --mem 4G --mail-type=all -c 1 --wrap="tar.sh 10 /n/scratch/users/l/ld32/1TRaw/small smallSbatchTar sbatch


### Exclsusive 10 jobs, meaning only one job run a certain node at the same time
sbatch -p short -t 4:0:0 -o slurm.esbatch.log -J eSbatch --mem 4G --mail-type=all -c 1 --wrap="tar.sh 10 \<sourceFolder\> \<destinationFolder\> esbatch

For example:
sbatch -p short -t 4:0:0 -o slurm.esbatch.log -J eSbatch --mem 4G --mail-type=all -c 1 --wrap="tar.sh 10 /n/scratch/users/l/ld32/1TRaw/small smallExSbatchTar esbatch 

## To summarize run: 
summarizeRun.sh \<destinationFolder\>

For example:

summarizeRun.sh smallSingleNodeTar

## To untar:
untar.sh \<cores\> \<sourceFolder\> \<destinationFolder\>

For example:

untar.sh 4 /source/dir/to/data /destination/dir/to/data





