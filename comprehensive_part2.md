## Part 3: SLURM Job Arrays

**Goal**: Learn when and how to schedule many similar, independent tasks at scale.

### What is a Job Array?
A job array is one submission that creates multiple independently scheduled array elements.
- The submission has a parent array ID, and each element has an array index. Most Slurm commands accept the combined form `<parent_id>_<index>` (for example, `8250375_0` or `8250375_1`). Each running element also has its own `SLURM_JOB_ID`.

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
#SBATCH --cpus-per-task=1
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

# Load modules needed by the job
module load fastqc

# Build the file list. The array index selects which file this task processes.
FILES=(01_data/*.fastq.gz)
TARGET="${FILES[$SLURM_ARRAY_TASK_ID]}"

# Derive a clean basename for naming logs and outputs (beginner-friendly)
sample_id=$(basename "$TARGET" .fastq.gz)        # e.g., bio_sample_01_R1

fastqc "$TARGET" -o $OUTPUT_DIR/ \
  > "$APP_LOGS/fastqc_slurm_array_${sample_id}.log" 2>&1
```

### How it works

- `--array=0-9` launches 10 array elements with `SLURM_ARRAY_TASK_ID` set to 0 through 9. This range must match the 10 files in the workshop dataset.
- Inside the script, `FILES=(01_data/*.fastq.gz)` builds the list of inputs; each array element picks `FILES[$SLURM_ARRAY_TASK_ID]`.
- `--cpus-per-task=1` and `--mem=2G` are per-element requests. With arrays, parallelism comes from many elements; keep each CPU and memory request aligned with one FastQC process.
- Log patterns `%A` (master job ID) and `%a` (array index) help separate per-task stdout/stderr.

Tips:
- If your files can be very large, increase `--time` and `--mem` per task accordingly.
- Avoid combining GNU Parallel with large arrays unless you adjust `--cpus-per-task` and the tool’s `-j/--threads` to avoid oversubscription.

Submit for all files in `01_data/`. Create `slurm_logs/` before submission because Slurm opens the output and error files before the script starts:

```bash
mkdir -p slurm_logs
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

`8250375` is the parent array ID, and the suffix after `_` is the array index (0–9). For example, `8250375_2` identifies index 2. Each line represents one array element.

**Alternative: Count files and submit a matching array**

```bash
# Count files and submit a matching array
shopt -s nullglob
FILES=(01_data/*.fastq.gz)
N=${#FILES[@]}
(( N > 0 )) || { echo "No FASTQ files found" >&2; exit 1; }
sbatch --array="0-$((N - 1))" 00_scripts/07_fastqc_array.slurm

# Alternatively, if you know there are 10 files (0..9):
# sbatch --array=0-9 00_scripts/07_fastqc_array.slurm
```

**Check one array element with `seff`**

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

**Inspect the complete array with `sacct`**

```bash
sacct -j 8250375 --format=JobID,JobName%20,State,Elapsed,MaxRSS,AllocCPUS,CPUTime,ExitCode
```

- `sacct`: SLURM's accounting command. It reports job and step history (finished and, depending on site config, running jobs) with detailed fields like state, elapsed wall time, peak memory (MaxRSS), allocated CPUs, and CPUTime. For arrays, pass the parent ID (e.g., `8250375`) to see all indices, or a specific one like `8250375_0`.
- `--format`: Format the output to show only the fields we care about. `%20` means 20 characters wide.
- `JobID`: The job ID.
- `JobName`: The job name.
- `State`: The state of the job. `COMPLETED` means the job finished successfully.
- `Elapsed`: The elapsed wall time.
- `MaxRSS`: The maximum resident memory recorded for a job step. 
- `AllocCPUS`: The number of allocated CPUs.
- `CPUTime`: Allocated core-wall time (`Elapsed × AllocCPUS`), not measured CPU use. Use `TotalCPU` or `seff` when you need actual CPU consumption.
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

Each array element therefore has a main accounting entry plus `.batch` and `.extern` step entries. The table is from the same earlier two-CPU run shown in the `seff` example.

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
  - SLURM Array: keep per-element CPU/memory requests modest (e.g., `--cpus-per-task=1–2`, `--mem=1–4G`) and let SLURM scale via many elements.
    ```bash
    shopt -s nullglob
    FILES=(01_data/*.fastq.gz)
    N=${#FILES[@]}
    (( N > 0 )) || { echo "No FASTQ files found" >&2; exit 1; }
    sbatch --array="0-$((N - 1))" 00_scripts/07_fastqc_array.slurm
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

You do not need to rerun every input. Identify failed indices with the logs or `sacct`, and then submit only the failed indices.

```bash
sbatch --array=46,89 00_scripts/07_fastqc_array.slurm
```

Slurm accepts comma-separated indices and ranges. This command creates a new parent array ID, so use the new ID when checking status and logs.



---

## Part 4: Strategy, Flowcharts & Wrap-up

How do you choose between the different methods? Start with task duration and quantity, and then account for per-task resources and local scheduler policy.

### Decision matrix

These are starting points, not universal limits. 

| Task Duration | Number of Tasks | Suggested Strategy |
| :---: | :---: | :--- |
| < 1 minute | Small enough for one node | **GNU Parallel** in one job |
| < 1 minute | Too many for one node | **Task grouping** in a throttled array |
| 1–15 minutes | < 50 | **GNU Parallel** in one job |
| 1–15 minutes | 50–1,000 | **Task grouping** or a throttled array |
| 15 minutes–4 hours | < 500 | **Slurm job array** |
| 15 minutes–4 hours | 500+ | **Slurm job array** with a `%` throttle |
| 4+ hours | Any | **Slurm job array**; consider checkpointing |
| Thousands of short tasks | Any | **Task grouping** to reduce scheduler overhead |

### Real-World Scenarios

#### Scenario 1: Image Thumbnails
> 5,000 images, each takes 3 seconds to resize.

**Best choice**: **GNU Parallel**  
- Individual tasks are too short for one array element each because scheduler overhead would dominate.
- At 16 concurrent tasks, the ideal compute time is about 16 minutes; request roughly 30 minutes to allow for startup and I/O, then refine the request from measured runs.

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
- `#SBATCH --time=HH:MM:SS` (requested runtime limit)
- `#SBATCH --mem=8G` (requested memory per node)
- `#SBATCH --cpus-per-task=4` (requested CPU cores per task)
- `#SBATCH --array=0-9` (Job array indices)
- `%A` and `%a` (Placeholders for Master Job ID and Array Index in `#SBATCH --output`)

