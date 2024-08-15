# tar Small Files
To decrease number of small file, keep the folder structure, tar all files in the same folder to a .tar file.

git clone https://github.com/ld32/tarSmallFiles.git

export PATH=$PWD/tarSmallFiles/bin:$PATH

## To run tar.sh:
sbatch -p short -t 4:0:0 -o slurm.esbatch.log -J eSbatch --mem 4G --mail-type=all -c 1 --wrap="tar.sh \<sourceFolder\> <folderLevel> <nJobs>" 

For example:

sbatch -p short -t 4:0:0 -J eSbatch --mem 4G --mail-type=all -c 1 --wrap="tar.sh /n/scratch/users/l/ld32/datasets/dorsalhorn_th/intersection/catmaided/1TRaw/small 2 4" -o destinationDir.log

## To check slurm short partition satuts, so that we have some jobs running, and pending or need submit more
checkQueue 

## To check jobs which are submitted for the folder:  
checkJobs \<destinationFolder\>

## To summarize run: 
summarizeRun \<destinationFolder\>

## To re-run failed jobs:
sbatch -p short -t 4:0:0 -J eSbatch --mem 4G --mail-type=all -c 1 --wrap="tar.sh \<sourceFolder\> <folderLevel> <nJobs>" -o destinationDir.log



