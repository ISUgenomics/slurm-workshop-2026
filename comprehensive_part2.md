## Part 3: SLURM Job Arrays

**Goal**: The "Correct" way to handle independent tasks at scale.

### What is a Job Array?
A Job Array is a single job submission that spawns multiple "tasks".
- **One Job ID** (Master ID), but many **Array Indices** (e.g., `8250375_0`, `8250375_1`).

**Why use Arrays?**
- **Independent**: If Task 5 fails, Task 6 still runs.
- **Throttle**: You can limit how many run at once (`%10`).
- **Logs**: Each task gets its own output file (`%A_%a.out`).
- **Retry**: You can re-submit *only* the failed indices.

---

Array jobs let you run the same command over many inputs (e.g., all FASTQ files) by indexing them with `SLURM_ARRAY_TASK_ID`. SLURM schedules each index as its own task.

### Example: FastQC over all files in 01_data/ using an array

Create `00_scripts/07_fastqc_array.slurm`:

```bash
#!/usr/bin/env bash

# ===== SLURM directives =====
#SBATCH --job-name=fastqc_array
#SBATCH --account=short_term
#SBATCH --partition=interactive
#SBATCH --time=00:05:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
# Use master job ID (%A) and array index (%a) for per-task logs
#SBATCH --output=slurm_logs/%x_%A_%a.out
#SBATCH --error=slurm_logs/%x_%A_%a.err
#SBATCH --array=0-9

set -euo pipefail

# Always start in the submission directory for predictable paths
cd "$SLURM_SUBMIT_DIR"

# Output directory 
OUTPUT_DIR=08_fastqc_slurm_array
SLURM_LOGS=slurm_logs
APP_LOGS=app_logs

# Ensure output directories exist
mkdir -p $SLURM_LOGS $APP_LOGS $OUTPUT_DIR

# Optional: load modules needed by the job
module load fastqc || true

# Build the file list. The array index selects which file this task processes.
FILES=(01_data/*.fastq.gz)
TARGET="${FILES[$SLURM_ARRAY_TASK_ID]}"

# Derive a clean basename for naming logs and outputs (beginner-friendly)
sample_id=$(basename "$TARGET" .fastq.gz)        # e.g., bio_sample_01_R1

fastqc "$TARGET" -o $OUTPUT_DIR/ \
  > "$APP_LOGS/fastqc_slurm_array_${sample_id}.log" 2>&1
```

### How it works

- `--array=0-9` launches 10 tasks with `SLURM_ARRAY_TASK_ID` set to 0..9.
- Inside the script, `FILES=(01_data/*.fastq.gz)` builds the list of inputs; each task picks `FILES[$SLURM_ARRAY_TASK_ID]`.
- `--cpus-per-task=1` and `--mem=2G` are per-task requests. With arrays, parallelism comes from many tasks; keep per-task CPU/memory modest.
- Log patterns `%A` (master job ID) and `%a` (array index) help separate per-task stdout/stderr.

Tips:
- If your files can be very large, increase `--time` and `--mem` per task accordingly.
- Avoid combining GNU Parallel with large arrays unless you adjust `--cpus-per-task` and the tool’s `-j/--threads` to avoid oversubscription.

Submit for all files in `01_data/`:

```bash
sbatch 00_scripts/07_fastqc_array.slurm
```

**Check the status of the job:**

```bash
squeue -u $USER
```

<details>
<summary>Output</summary>
<pre>
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
         8250375_1 interacti fastqc_a satheesh  R       0:01      1 nova21-1
         8250375_2 interacti fastqc_a satheesh  R       0:01      1 nova21-1
         8250375_3 interacti fastqc_a satheesh  R       0:01      1 nova21-1
         8250375_4 interacti fastqc_a satheesh  R       0:01      1 nova21-1
         8250375_5 interacti fastqc_a satheesh  R       0:01      1 nova21-1
         8250375_6 interacti fastqc_a satheesh  R       0:01      1 nova21-1
         8250375_7 interacti fastqc_a satheesh  R       0:01      1 nova21-1
         8250375_8 interacti fastqc_a satheesh  R       0:01      1 nova21-1
         8250375_9 interacti fastqc_a satheesh  R       0:01      1 nova21-1
         8250375_0 interacti fastqc_a satheesh  R       0:02      1 nova21-1
</pre>
</details>

**Explanation of the output**

JOBID: 8250375_0, 8250375_2, …, 8250375_9
8250375 is the master job ID; the suffix _ is the array task index (0–9). Each line is one array task.

**Alternative:Count files and submit a matching array**

```bash
# Count files and submit a matching array
N=$(ls 01_data/*.fastq.gz | wc -l)
sbatch --array=0-$((N-1)) 00_scripts/07_fastqc_array.slurm

# Alternatively, if you know there are 10 files (0..9):
# sbatch --array=0-9 00_scripts/07_fastqc_array.slurm
```

**seff the job**

```bash
seff 8250375_0
```

<details>
<summary>Output</summary>
<pre>
Job ID: 8250376
Array Job ID: 8250375_0
Cluster: nova
User/Group: satheesh/domain users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 2
CPU Utilized: 00:00:10
CPU Efficiency: 50.00% of 00:00:20 core-walltime
Job Wall-clock time: 00:00:10
Memory Utilized: 302.76 MB
Memory Efficiency: 14.78% of 2.00 GB (2.00 GB/node)
</pre>
</details>

**sacct the job**

```bash
sacct -j 8250375 --format=JobID,JobName%20,State,Elapsed,MaxRSS,AllocCPUS,CPUTime,ExitCode
```

- `sacct`: SLURM's accounting command. It reports job and step history (finished and, depending on site config, running jobs) with detailed fields like state, elapsed wall time, peak memory (MaxRSS), allocated CPUs, and CPUTime. For arrays, pass the parent ID (e.g., `8250375`) to see all indices, or a specific one like `8250375_0`.
- `--format`: Format the output to show only the fields we care about. `%20` means 20 characters wide.
- `JobID`: The job ID.
- `JobName`: The job name.
- `State`: The state of the job. `COMPLETED` means the job finished successfully.
- `Elapsed`: The elapsed wall time.
- `MaxRSS`: The peak memory usage.
- `AllocCPUS`: The number of allocated CPUs.
- `CPUTime`: The CPU time used.
- `ExitCode`: The exit code of the job.

<details>
<summary>Output</summary>
<pre>
JobID                     JobName      State    Elapsed     MaxRSS  AllocCPUS    CPUTime ExitCode
------------ -------------------- ---------- ---------- ---------- ---------- ---------- --------
8250375_0            fastqc_array  COMPLETED   00:00:10                     2   00:00:20      0:0
8250375_0.b+                batch  COMPLETED   00:00:10    310024K          2   00:00:20      0:0
8250375_0.e+               extern  COMPLETED   00:00:10                     2   00:00:20      0:0
8250375_1            fastqc_array  COMPLETED   00:00:09                     2   00:00:18      0:0
8250375_1.b+                batch  COMPLETED   00:00:09    320032K          2   00:00:18      0:0
8250375_1.e+               extern  COMPLETED   00:00:09                     2   00:00:18      0:0
8250375_2            fastqc_array  COMPLETED   00:00:17                     2   00:00:34      0:0
8250375_2.b+                batch  COMPLETED   00:00:17    302488K          2   00:00:34      0:0
8250375_2.e+               extern  COMPLETED   00:00:17                     2   00:00:34      0:0
8250375_3            fastqc_array  COMPLETED   00:00:17                     2   00:00:34      0:0
8250375_3.b+                batch  COMPLETED   00:00:17    290540K          2   00:00:34      0:0
8250375_3.e+               extern  COMPLETED   00:00:17                     2   00:00:34      0:0
8250375_4            fastqc_array  COMPLETED   00:00:09                     2   00:00:18      0:0
8250375_4.b+                batch  COMPLETED   00:00:09    292888K          2   00:00:18      0:0
8250375_4.e+               extern  COMPLETED   00:00:09                     2   00:00:18      0:0
8250375_5            fastqc_array  COMPLETED   00:00:09                     2   00:00:18      0:0
8250375_5.b+                batch  COMPLETED   00:00:09    285000K          2   00:00:18      0:0
8250375_5.e+               extern  COMPLETED   00:00:09                     2   00:00:18      0:0
8250375_6            fastqc_array  COMPLETED   00:00:09                     2   00:00:18      0:0
8250375_6.b+                batch  COMPLETED   00:00:09    335176K          2   00:00:18      0:0
8250375_6.e+               extern  COMPLETED   00:00:09                     2   00:00:18      0:0
8250375_7            fastqc_array  COMPLETED   00:00:09                     2   00:00:18      0:0
8250375_7.b+                batch  COMPLETED   00:00:09    333360K          2   00:00:18      0:0
8250375_7.e+               extern  COMPLETED   00:00:09                     2   00:00:18      0:0
8250375_8            fastqc_array  COMPLETED   00:00:08                     2   00:00:16      0:0
8250375_8.b+                batch  COMPLETED   00:00:08    308852K          2   00:00:16      0:0
8250375_8.e+               extern  COMPLETED   00:00:08                     2   00:00:16      0:0
8250375_9            fastqc_array  COMPLETED   00:00:13                     2   00:00:26      0:0
8250375_9.b+                batch  COMPLETED   00:00:13    294728K          2   00:00:26      0:0
8250375_9.e+               extern  COMPLETED   00:00:13                     2   00:00:26      0:0
</pre>
</details>

- `8250375_0` → your array task with index 0.
- `8250375_0.bat+` (batch) → the batch step where your commands ran.
- `8250375_0.ext+` (extern) → the extern step, which tracks resource usage tied to the allocation itself (not your script directly).
- `8250375_1` → the array task with index 1, and so on.

So each array task has a main job entry, plus `.batch` and `.extern` sub-entries.

**More Reading**

<details>
<summary><strong>GNU Parallel vs SLURM Array</strong></summary>

- What they do
  - GNU Parallel: run many commands concurrently inside a single job allocation.
  - SLURM Array: launch many tasks (one per input) as separate scheduled tasks.

- When to use which
  - GNU Parallel
    - Best when you already have one allocation (interactive srun or one batch job) and want to fan out work within it.
    - Simple to cap concurrency and share memory/CPUs among tasks on one node.
  - SLURM Array
    - Best when you want per-input scheduling, isolation, and accounting — and the ability to scale across nodes.
    - Easy to retry only failed indices.

- Resource accounting and debugging
  - GNU Parallel
    - One job’s stdout/stderr unless you manually split logs per file.
    - One seff summary for the whole job; per-file timing via your own logs.
  - SLURM Array
    - Per-task stdout/stderr and per-task seff/sacct.
    - Clear which inputs failed or were slow.

- Failure isolation
  - GNU Parallel: a failing command doesn’t necessarily stop the whole job; handle exit codes yourself.
  - SLURM Array: failures are isolated to their indices; other tasks continue.

- Queue behavior and limits
  - GNU Parallel: queue once, then manage parallelism internally on the node you obtained.
  - SLURM Array: each task queues separately; site policies may cap concurrent array tasks.

- Avoid oversubscription
  - GNU Parallel inside SLURM: align -j with CPUs you requested.
    ```bash
    parallel -j "$SLURM_CPUS_PER_TASK" \
      'fastqc {1} -o 02h_fastqc_parallel/ > logs/02h_fastqc_parallel_{1/.}.log 2>&1' \
      ::: 01_data/*.fastq.gz
    ```
  - SLURM Array: keep per-task CPU/memory modest (e.g., --cpus-per-task=1–2, --mem=1–4G) and let SLURM scale via many tasks.
    ```bash
    N=$(ls 01_data/*.fastq.gz | wc -l)
    sbatch --array=0-$((N-1)) 00_scripts/07_fastqc_array.slurm
    ```

- Rules of thumb
  - Small dataset, one node available now → GNU Parallel for quick turnaround.
  - Many files, want per-input tracking/retry, or need to scale across nodes → SLURM Array.
  - Always align concurrency with resources to avoid oversubscribing CPUs/memory.

</details>


### Handling Failures: The "Swiss Cheese" Array

Imagine you ran 100 jobs.
- Tasks 0-45: Success
- Task 46: FAILED
- Tasks 47-88: Success
- Task 89: FAILED

You don't want to re-run everything. Check which IDs failed (look at logs or `sacct`).
Then submit **only the holes**:

```bash
sbatch --array=46,89 00_scripts/07_fastqc_array.slurm
```
Slurm allows comma-separated lists and ranges!



---

## Part 4: Strategy, Flowcharts & Wrap-up

How do you choose between the different methods? Use this simple rule of thumb based on **Task Duration** and **Quantity**.

### The Decision Matrix

| Task Duration | Number of Tasks | Best Strategy |
| :---: | :---: | :--- |
| < 1 minute | Any | **GNU Parallel** |
| 1-15 minutes | < 50 | **GNU Parallel** in a single job |
| 1-15 minutes | 50-1000 | **GNU Parallel** split into multiple jobs |
| 15 min - 4 hours | < 500 | **Slurm Job Array** |
| 15 min - 4 hours | 500+ | **Slurm Job Array** with `%` throttle |
| 4+ hours | Any | **Slurm Job Array** (consider checkpointing) |
| 1000s of short tasks | Any | **Task Grouping** (bundle tasks into array elements) |

### Real-World Scenarios

#### Scenario 1: Image Thumbnails
> 5,000 images, each takes 3 seconds to resize.

**Best choice**: **GNU Parallel**  
- Tasks are too short for arrays (scheduler overhead would dominate this).
- Pack into a single 2-hour job running 16 at a time.

#### Scenario 2: RNA-seq Alignment
> 48 samples, each takes 2 hours, uses 8 CPUs and 32GB RAM.

**Best choice**: **Slurm Job Array**  
- Long-running tasks benefit from independent logging.
- Each sample may have different failure modes, and it is easy to re-run failed samples.

#### Scenario 3: Parameter Sweep
> 10,000 simulations, each takes 30 seconds.

**Best choice**: **Task Grouping with GNU Parallel**  
- 10,000 array tasks would overwhelm the scheduler.
- Bundle 100 simulations per array task (100 array elements) using bash logic to split them.

---

### SLURM Quick Reference Cheat Sheet

| Command | Action |
| :--- | :--- |
| `sinfo` | View cluster and partition status |
| `squeue -u $USER` | View your currently running and pending jobs |
| `scancel <JOBID>` | Cancel a specific job |
| `sbatch script.sh` | Submit a batch job script |
| `srun ... --pty bash` | Start an interactive terminal session on a compute node |
| `seff <JOBID>` | View CPU and Memory efficiency of a completed job |
| `sacct -j <JOBID>` | View detailed accounting history of a job (or array) |

**Key Script Directives**
- `#SBATCH --time=HH:MM:SS` (Max runtime)
- `#SBATCH --mem=8G` (Max memory per node)
- `#SBATCH --cpus-per-task=4` (Number of cores)
- `#SBATCH --array=0-9` (Job array indices)
- `%A` and `%a` (Placeholders for Master Job ID and Array Index in `#SBATCH --output`)

