# Comprehensive Guide: From Bash Scripts to SLURM Arrays

**Workshop Duration Estimate: ~4 Hours**

---

## Quick start

- VS Code Server on Nova OnDemand through a browser: `https://nova-ondemand.its.iastate.edu/`

  ```
  Account: short_term
  Partition: interactive
  Number of hours: 4
  Number of tasks per node: 10
  Memory Required: 8G
  Working Directory: /work/short_term/slurm_workshop
  ```

- Create a directory for your work, clone the workshop repository, and enter it:

```bash
mkdir -p "$USER"
cd "$USER"
git clone https://github.com/ISUgenomics/slurm-workshop-2026.git
cd slurm-workshop-2026
```

- Copy the workshop data into the repository so that the paths used below resolve correctly:

```bash
cp -r /work/short_term/$USER/01_data .
```

You should now be in the `slurm-workshop-2026/` directory. Run the remaining commands from this directory unless instructed otherwise.

## Part 1: Running commands and recording them in a script

### What is a job?

- A job is a unit of work submitted to the scheduler. It may run one command, a script, or several related steps using the resources you request.

### What is a head node?

- A head node is a node that is used to control the cluster.
- It is the node that will be used to submit your jobs to the cluster.
- Remember, we DO NOT run intensive jobs on this node. 

### What is a compute node?

- A compute node is a node that is used to run your intensive jobs.

---

## Interactive jobs (quick testing)

If you want a short interactive session on a compute node:

**srun**

```bash
srun --account=short_term --partition=interactive \
     --time=00:15:00 --cpus-per-task=2 --mem=2G \
     --pty bash
```

You’ll get a shell on a compute node where you can run commands interactively. Exit with `exit` or Ctrl-D.

### What are the files in the data folder?

```bash
ls 01_data/
```

<details>
<summary>Output</summary>
<pre>
bio_sample_01_R1.fastq.gz  bio_sample_02_R1.fastq.gz  bio_sample_03_R1.fastq.gz  bio_sample_04_R1.fastq.gz  bio_sample_05_R1.fastq.gz
bio_sample_01_R2.fastq.gz  bio_sample_02_R2.fastq.gz  bio_sample_03_R2.fastq.gz  bio_sample_04_R2.fastq.gz  bio_sample_05_R2.fastq.gz
</pre>
</details>

### Checking the quality of the reads using FastQC

#### One file

```bash
module purge
module load fastqc
mkdir -p 02_fastqc
fastqc 01_data/bio_sample_01_R1.fastq.gz -o 02_fastqc/
```
The `-p` flag tells `mkdir` to create the directory if it does not exist and not to report an error if it already exists.

Once the program is run, it will create a directory called `02_fastqc` and put the output files in it.

```bash
ls 02_fastqc
```

<details>
<summary>Output</summary>
<pre>
bio_sample_01_R1_fastqc.html  bio_sample_01_R1_fastqc.zip
</pre>
</details>

Remove the folders created

```bash
rm -r 02_fastqc
```

Open `00_scripts/01_fastqc.sh` in the script window. 

```bash
module purge
module load fastqc
mkdir -p 02_fastqc logs
fastqc 01_data/bio_sample_01_R1.fastq.gz -o 02_fastqc/ > logs/01_fastqc.log 2>&1
```

- Explanation of the command in the script:
  - `fastqc 01_data/bio_sample_01_R1.fastq.gz -o 02_fastqc/` runs FastQC on the input file and writes the results to the `02_fastqc/` directory.
  - `> logs/01_fastqc.log` redirects standard output (stdout, file descriptor 1) to the log file, overwriting it if it exists.
  - `2>&1` redirects standard error (stderr, file descriptor 2) to the same destination as stdout, so both stdout and stderr end up in `logs/01_fastqc.log`.
  - This pattern is useful to capture all program messages for troubleshooting and record-keeping. Ensure `logs/` exists (we created it with `mkdir -p logs`).
  - Tip: If you want to see the output live and also save it, you can use `tee`, e.g., `... 2>&1 | tee logs/01_fastqc.log`.

**Make the script an executable file**

```bash
chmod +x 00_scripts/01_fastqc.sh
```

**Run the script**

```bash
time ./00_scripts/01_fastqc.sh 
```

**Output**

```
real    0m6.949s
user    0m7.568s
sys     0m0.597s
```

- `real`: The wall-clock time — how long the command took from start to finish
          Includes everything: CPU time, waiting for I/O (disk, network), scheduling delays, etc.
- `user`: The amount of CPU time spent in user space (your program’s own code, libraries, calculations).
          Example: crunching numbers in Python, sorting data, compressing a file.
- `sys` : The amount of CPU time spent in kernel space (system calls and OS overhead).
          Example: reading/writing files, allocating memory, handling I/O requests.

#### Multiple files (looping through files)

A simple example:

```bash
# A simple loop example: list files in 01_data/
for file in 01_data/*.fastq.gz 
do
  echo "Found file: $file"
done
```

- The `for ... in ... do ... done` construct repeats the commands between `do` and `done` for each matched file.
- `01_data/*.fastq.gz` expands (globs) to all FASTQ files in the `01_data/` directory.
- `$file` is a shell variable that holds the current filename; `echo` prints text to the terminal.

**Run `FastQC` on all files in `01_data/`**

```bash
module purge
module load fastqc

mkdir -p 03_fastqc_loop

for file in 01_data/*.fastq.gz
do
  echo "Running FastQC on: $file"
  fastqc $file -o 03_fastqc_loop/ > logs/02_fastqc_loop.log 2>&1
done
```

Save this script as `02_fastqc_loop.sh` in `00_scripts` directory.

Make it executable:

```bash
chmod +x 00_scripts/02_fastqc_loop.sh
```

**Run the script**

```bash
time ./00_scripts/02_fastqc_loop.sh
```

<details>
<summary>Output</summary>
<pre>
Running FastQC on: 01_data/bio_sample_01_R1.fastq.gz
Running FastQC on: 01_data/bio_sample_01_R2.fastq.gz
Running FastQC on: 01_data/bio_sample_02_R1.fastq.gz
Running FastQC on: 01_data/bio_sample_02_R2.fastq.gz
Running FastQC on: 01_data/bio_sample_03_R1.fastq.gz
Running FastQC on: 01_data/bio_sample_03_R2.fastq.gz
Running FastQC on: 01_data/bio_sample_04_R1.fastq.gz
Running FastQC on: 01_data/bio_sample_04_R2.fastq.gz
Running FastQC on: 01_data/bio_sample_05_R1.fastq.gz
Running FastQC on: 01_data/bio_sample_05_R2.fastq.gz

real    1m12.560s
user    1m37.585s
sys     0m2.792s
</pre>
</details>

Check the log file:

```bash
cat logs/02_fastqc_loop.log
```

<details>
<summary>Output</summary>
<pre>
Started analysis of bio_sample_05_R2.fastq.gz
Approx 5% complete for bio_sample_05_R2.fastq.gz
Approx 10% complete for bio_sample_05_R2.fastq.gz
Approx 15% complete for bio_sample_05_R2.fastq.gz
Approx 20% complete for bio_sample_05_R2.fastq.gz
Approx 25% complete for bio_sample_05_R2.fastq.gz
Approx 30% complete for bio_sample_05_R2.fastq.gz
Approx 35% complete for bio_sample_05_R2.fastq.gz
Approx 40% complete for bio_sample_05_R2.fastq.gz
Approx 45% complete for bio_sample_05_R2.fastq.gz
Approx 50% complete for bio_sample_05_R2.fastq.gz
Approx 55% complete for bio_sample_05_R2.fastq.gz
Approx 60% complete for bio_sample_05_R2.fastq.gz
Approx 65% complete for bio_sample_05_R2.fastq.gz
Approx 70% complete for bio_sample_05_R2.fastq.gz
Approx 75% complete for bio_sample_05_R2.fastq.gz
Approx 80% complete for bio_sample_05_R2.fastq.gz
Approx 85% complete for bio_sample_05_R2.fastq.gz
Approx 90% complete for bio_sample_05_R2.fastq.gz
Approx 95% complete for bio_sample_05_R2.fastq.gz
Approx 100% complete for bio_sample_05_R2.fastq.gz
Analysis complete for bio_sample_05_R2.fastq.gz
</pre>
</details>

The log file shows the progress of the FastQC analysis for just the last file.

Let us now make sure that we have a log file for each file. 

```bash
module purge
module load fastqc

INPUT_DIR=01_data
OUTPUT_DIR=04_fastqc_loop_samplename
LOG_DIR=logs

mkdir -p $OUTPUT_DIR $LOG_DIR

for file in $INPUT_DIR/*.fastq.gz 
do  
  sample_id=$(basename "$file" .fastq.gz)
  echo "Running FastQC on: $sample_id"
  fastqc $file -o $OUTPUT_DIR/ > $LOG_DIR/03_fastqc_loop_$sample_id.log 2>&1
done
```

Using shell variables in the loop helps to make the script more readable, maintainable, and reusable.

Save this script as `03_fastqc_loop_samplename.sh` in `00_scripts` directory.

Make it executable:

```bash
chmod +x 00_scripts/03_fastqc_loop_samplename.sh
```

**Run the script:**

```bash
time ./00_scripts/03_fastqc_loop_samplename.sh
```

<details>
<summary>Output</summary>
<pre>
Running FastQC on: bio_sample_01_R1
Running FastQC on: bio_sample_01_R2
Running FastQC on: bio_sample_02_R1
Running FastQC on: bio_sample_02_R2
Running FastQC on: bio_sample_03_R1
Running FastQC on: bio_sample_03_R2
Running FastQC on: bio_sample_04_R1
Running FastQC on: bio_sample_04_R2
Running FastQC on: bio_sample_05_R1
Running FastQC on: bio_sample_05_R2

real    1m11.971s
user    1m31.266s
sys     0m3.074s
</pre>
</details>

Check the log files:

```bash
less logs/*bio_sample*log
```

Using `less` we can view the contents of the log files. To move from one file to the next, use the `:n` command within `less`. To move to the previous file, use the `:p` command.

To check if all files have been processed, we can use the `grep` command.

```bash
grep "Analysis complete" logs/*bio_sample*log
```

<details>
<summary>Output</summary>
<pre>
logs/02_fastqc_loop_bio_sample_01_R1.log:Analysis complete for bio_sample_01_R1.fastq.gz
logs/02_fastqc_loop_bio_sample_01_R2.log:Analysis complete for bio_sample_01_R2.fastq.gz
logs/02_fastqc_loop_bio_sample_02_R1.log:Analysis complete for bio_sample_02_R1.fastq.gz
logs/02_fastqc_loop_bio_sample_02_R2.log:Analysis complete for bio_sample_02_R2.fastq.gz
logs/02_fastqc_loop_bio_sample_03_R1.log:Analysis complete for bio_sample_03_R1.fastq.gz
logs/02_fastqc_loop_bio_sample_03_R2.log:Analysis complete for bio_sample_03_R2.fastq.gz
logs/02_fastqc_loop_bio_sample_04_R1.log:Analysis complete for bio_sample_04_R1.fastq.gz
logs/02_fastqc_loop_bio_sample_04_R2.log:Analysis complete for bio_sample_04_R2.fastq.gz
logs/02_fastqc_loop_bio_sample_05_R1.log:Analysis complete for bio_sample_05_R1.fastq.gz
logs/02_fastqc_loop_bio_sample_05_R2.log:Analysis complete for bio_sample_05_R2.fastq.gz
</pre>
</details>


#### Why use GNU Parallel?
As a beginner, one might submit one tiny job per file in a loop or append `&` to every command without limiting how many run at once.
- **Why avoid many tiny `sbatch` submissions?** Large numbers of short jobs add scheduler overhead and are difficult to monitor. For independently scheduled work, prefer a job array and follow the site's array-size policy.
- **Why avoid unbounded background processes (`&`)?** They can oversubscribe the CPUs or exhaust the memory assigned to your node.

GNU Parallel manages a bounded queue of tasks *inside* one allocation. Set its job count to the CPUs and memory you actually requested.

#### Multiple files (GNU Parallel)

Let us now use GNU Parallel to run the FastQC analysis on all files in parallel.
The first step is go for a dry run to see what commands will be executed.

```bash
module load parallel 
mkdir -p 05_fastqc_parallel
parallel --dry-run -j 10 fastqc {} -o 05_fastqc_parallel/ ::: 01_data/*.fastq.gz
```

- `parallel --dry-run -j 10 fastqc {} -o 05_fastqc_parallel/ ::: 01_data/*.fastq.gz`
  - `--dry-run` prints the commands that would be executed, without running them. Use this to verify first.
  - `-j 10` means run up to 10 jobs at the same time (choose based on cores available to you).
  - `fastqc {}` is the command template; `{}` will be replaced by each input filename.
  - `-o 05_fastqc_parallel/` sends FastQC outputs into that directory.
  - `:::` introduces the list of inputs to feed to GNU Parallel; here the shell expands `01_data/*.fastq.gz` to all matching files.

To actually run the commands (not just show them), remove `--dry-run`:

```bash
module purge
module load parallel
module load fastqc 

mkdir -p 05_fastqc_parallel

parallel -j10 \
  'fastqc {1} -o 05_fastqc_parallel/ > logs/04_fastqc_parallel_{1/.}.log 2>&1' \
  ::: 01_data/*.fastq.gz
```

- The trailing `\` characters are line continuations so the long command is split across multiple lines for readability.
- Quotes `'...'` keep the whole FastQC template as one string so that GNU Parallel, not your shell, substitutes `{1}` and `{1/.}`.
- `{1}` is the first input argument (each file matched by the glob). With a single input source, `{}` and `{1}` are equivalent.
- `{1/.}` is a GNU Parallel filename modifier: it expands to the basename of the first input with its final extension removed. Because the inputs end in `.fastq.gz`, only `.gz` is removed, producing log names such as `logs/04_fastqc_parallel_bio_sample_01_R1.fastq.log`.
- `> logs/04_fastqc_parallel_{1/.}.log 2>&1` writes both stdout and stderr of each FastQC run to a separate log file derived from the input name.

Add the above script to `00_scripts/04_fastqc_parallel.sh`.

Make it executable:

```bash
chmod +x 00_scripts/04_fastqc_parallel.sh
```

**Run the script**

```bash
time ./00_scripts/04_fastqc_parallel.sh
```

<details>
<summary>Output</summary>
<pre>
real    0m26.453s
user    2m1.143s
sys     0m3.962s
</pre>
</details>

- **Why `user` > `real` here**
  - Because we ran multiple tasks concurrently (e.g., via loops or GNU Parallel), CPU time across cores adds up. If 8 cores each do ~15 seconds of work, `user` could be ~120 seconds while `real` is ~15–30 seconds.

- **How to interpret**
  - Use `real` to estimate elapsed time for the end-to-end run (what you experience).
  - Use `user + sys` to gauge how much total CPU work was consumed. Large gaps between `real` and `user+sys` often indicate parallelism; very small `user`/`sys` compared to `real` can indicate waiting on I/O.

#### Cleaner shell script

```bash
#!/usr/bin/env bash

set -euo pipefail # error handling: 
                  # -e: exit immediately if any command returns a non-zero exit status (error) 
                  # -u: treat unset variables as an error and exit (useful for debugging)
                  # -o pipefail: exit if any command in a pipeline fails (useful for debugging)

# Directories
# Input directory
INPUT_DIR="01_data"

# Output directory
OUTPUT_DIR="06_fastqc_parallel_improved"

# Log directory
LOG_DIR="logs"

# Create required directories
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# make them visible to subshells that parallel spawns
export OUTPUT_DIR LOG_DIR INPUT_DIR

# Load required modules
module load parallel
module load fastqc

# Run FastQC
parallel -j10 \
  'fastqc "{1}" -o "$OUTPUT_DIR/" > "$LOG_DIR/05_fastqc_parallel_improved_{1/.}.log" 2>&1' \
  ::: $INPUT_DIR/*.fastq.gz
```

Add the above script to `00_scripts/05_fastqc_parallel_improved.sh`.

Make it executable:

```bash
chmod +x 00_scripts/05_fastqc_parallel_improved.sh
```

Run the script:

```bash
time ./00_scripts/05_fastqc_parallel_improved.sh
```

<details>
<summary>Output</summary>
<pre>
real    0m30.624s
user    2m53.930s
sys     0m6.853s
</pre>
</details>


---

## Part 2: Building a SLURM script

The Slurm Workload Manager is the job scheduler that manages who gets to use the cluster’s compute nodes and for how long. You log in to a head/login node to prepare your work, and then ask Slurm to run jobs on compute nodes with the resources you request.

If you remember just one thing: you don’t run heavy work directly on the head node. You ask SLURM to run it for you on a compute node.

---

## Why do we use SLURM?

- It shares the cluster fairly among many users.
- It finds and reserves the resources you need (CPUs, memory, time).
- It tracks your job, captures logs, and reports status.

---

## Key words

- **Cluster**: Many connected computers that can work in parallel.
- **Head/Login node**: Where you log in, write scripts, submit jobs. Do not run heavy jobs here.
- **Compute node**: Where your jobs actually run.
- **Job**: A task you ask SLURM to run. It gets a numeric Job ID.
- **Partition (queue)**: A grouping of nodes with certain limits (e.g., time, size). You submit jobs to a partition.
- **Account**: The project or allocation that pays for/authorizes compute usage.
- **Resources**: CPUs/cores, memory (RAM), time limit.
- **Job states**: PENDING (PD, waiting), RUNNING (R), COMPLETED (CD), FAILED (F), CANCELLED (CA), COMPLETING (CG).

---

## Two ways to use SLURM

- **Batch job (sbatch)**: You submit a script and SLURM runs it in the background on a compute node. Best for pipelines.
- **Interactive job (srun)**: You request a shell on a compute node for hands-on work or quick testing.

---

## Essential commands

```bash
# What is running right now for me?
squeue -u $USER

# What partitions exist? (short summary)
sinfo

# What partitions exist? (detailed summary)
sinfo -p <partition_name>

# Submit a batch job
sbatch <script_name.slurm>

# Cancel a job by its Job ID
scancel <JOBID>

# Show info about a job
scontrol show job <JOBID>
```

Tip: Use `history | grep sbatch` to find previous submissions.

---

## Running a SLURM job

We are going to use the `05_fastqc_parallel_improved.sh` script as an example. In the `05_fastqc_parallel_improved.sh` script, change the output directory to `07_fastqc_slurm`.

```bash
#!/usr/bin/env bash

# ===== SLURM directives (read by the scheduler) =====
# a short name for your job
#SBATCH --job-name=fastqc
# account/allocation
#SBATCH --account=short_term
# partition/queue
#SBATCH --partition=interactive
# max wall time (hh:mm:ss)
#SBATCH --time=00:05:00
# number of nodes
#SBATCH --nodes=1
# number of CPU cores
#SBATCH --cpus-per-task=10
# memory per node
#SBATCH --mem=8G
# STDOUT (%x=job-name, %j=jobid)
#SBATCH --output=logs/%x_%j.out
# STDERR
#SBATCH --error=logs/%x_%j.err
# email address
#SBATCH --mail-user=user@iastate.edu
# send email when the job ends or fails
#SBATCH --mail-type=END,FAIL

set -euo pipefail

00_scripts/05_fastqc_parallel_improved.sh
```

**Explanation of the directives above**

- `#SBATCH --job-name=fastqc`
  - Short, human-friendly job name. Appears in `squeue`, logs, and emails.

- `#SBATCH --account=short_term`
  - Allocation/account to charge; required to authorize the job.

- `#SBATCH --partition=interactive`
  - Which queue/partition to use. Partitions differ in limits and availability.

- `#SBATCH --time=00:05:00`
  - Maximum wall-clock time. SLURM will stop the job if it exceeds 5 minutes.

- `#SBATCH --nodes=1`
  - Number of compute nodes requested. Most single-node tools/pipelines use 1.

- `#SBATCH --cpus-per-task=10`
  - CPU cores available to your task. Match this to your internal parallelism (e.g., GNU Parallel `-j 10` or a tool’s `--threads 10`).

- `#SBATCH --mem=8G`
  - Total memory on the node reserved for your job. Ensure it covers the peak combined usage of all concurrent processes.

- `#SBATCH --output=logs/%x_%j.out`
  - File for standard output (STDOUT). `%x` = job name, `%j` = job ID (e.g., `logs/fastqc_8249780.out`).

- `#SBATCH --error=logs/%x_%j.err`
  - File for standard error (STDERR). Check here for module load messages and errors.

- `#SBATCH --mail-user=user@iastate.edu`
  - Email address to receive job notifications. Replace this placeholder with your own address, or remove both mail directives if you do not want notifications.

- `#SBATCH --mail-type=END,FAIL`
  - Sends a notification when the job ends or fails. Other supported event types depend on the cluster configuration.

Notes:
- If you launch 10 FastQC processes in parallel, `--cpus-per-task=10` is appropriate; otherwise, lower it to match your actual concurrency.
- Memory must scale with concurrency. If each process needs ~1G and you run 10 in parallel, consider `--mem=10G` or more.
- The job starts in the submission directory by default; to be explicit, add `cd "$SLURM_SUBMIT_DIR"` near the top of the script.

Save the above script as `06_fastqc.slurm` in the `00_scripts` directory.

**How to submit and check:**

Create the scheduler log directory *before* submission; Slurm opens the output and error files before the script begins running.

```bash
mkdir -p logs
sbatch 00_scripts/06_fastqc.slurm
```

**Check the status of the job:**

```bash
squeue -u $USER
```

<details>
<summary>Output</summary>
<pre>
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
8249780 interacti   fastqc satheesh  R       0:01      1 nova21-1
</pre>
</details>

**Check logs**

```bash
ls -lh logs/
cat logs/fastqc_*.out
cat logs/fastqc_*.err
```

In this case, the `fastqc_*.out` file may be empty because the FastQC command redirects its own output to per-file application logs. The `fastqc_*.err` file contains messages written to standard error by the batch wrapper, if any. Check both the Slurm logs and the per-file logs when troubleshooting.

**Check efficiency**

```bash
seff 8249780
```

`seff` is a useful tool to check the efficiency of a job. It shows the actual time the job spent using the CPU and the percentage of the requested CPU time that was actually used.

<pre>
Job ID: 8249780
Cluster: nova
User/Group: satheesh/domain users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 10
CPU Utilized: 00:01:59
CPU Efficiency: 59.50% of 00:03:20 core-walltime
Job Wall-clock time: 00:00:20
Memory Utilized: 3.27 GB
Memory Efficiency: 40.83% of 8.00 GB (8.00 GB/node)
</pre>

**Explanation of efficiency metrics**

- **CPU Utilized**: The actual time the job spent using the CPU. In this case, the job used the CPU for 1 minute and 59 seconds.
- **CPU Efficiency**: The percentage of the requested CPU time that was actually used. Here, the job used 59.50% of the 3 minutes and 20 seconds of CPU time it requested.
- **Job Wall-clock time**: The elapsed time from when the job started on a compute node until it finished. It includes setup, I/O, and computation, but not time spent pending in the queue.
- **Memory Utilized**: The amount of memory the job actually used. In this case, the job used 3.27 GB of memory.
- **Memory Efficiency**: The percentage of the requested memory that was actually used. Here, the job used 40.83% of the 8 GB of memory it requested.

---

### The Efficiency Mindset: What happens if you guess wrong?

When writing a SLURM script, you request time, memory, and CPUs.
1. **Request too little**: The job may be terminated for exceeding its time or memory limit.
2. **Request too much**:
   - The job may wait longer because the scheduler must find a larger resource slot.
   - Reserved resources may sit idle instead of serving other jobs.
   - Depending on site policy, allocated resources may count toward fair-share usage or billing.

**Rule of thumb**: Run representative inputs first, inspect them with `seff` and `sacct`, and add a reasonable safety margin. A 20–30% margin can be a useful starting point, but input variability and cluster policy should guide the final request.

**Why this matters for arrays**:
Over-requesting 4 GB for each element of a 1,000-task array represents 4 TB of unnecessary memory requests across the array. That can reduce scheduling opportunities and cluster throughput, especially without a concurrency limit.

---

### Activity: Debugging a Failed Job

In reality, jobs will fail frequently due to typos or missing paths. Let's look at how to identify why.

1. **Check the `.err` file**: In this script, Slurm sends the batch wrapper's standard output to `.out` and standard error to `.err`. Shell errors (such as missing commands) and Python tracebacks normally appear in `.err` unless the application redirects them elsewhere.
   
```bash
cat logs/fastqc_8249780.err
```
If you see `command not found`, you forgot to `module load`. If you see `No such file or directory`, your path to `01_data` is wrong.
