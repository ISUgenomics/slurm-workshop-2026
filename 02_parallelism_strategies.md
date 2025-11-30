# Module 2: Scaling Up - Parallelism Basics

**Goal**: Process multiple files without submitting 100 separate jobs (yet).

## The Scenario
You have 20 files (`sample_00.fastq` to `sample_19.fastq`). You want to process all of them.

## Strategy 1: The "Bad" Way (Looping sbatch)
A common beginner mistake is to write a loop that submits a job for every file.

```bash
# DON'T DO THIS!
for file in 01_data/*.fastq; do
    sbatch 00_scripts/process_sample.sh $file ...
done
```

**Why is this bad?**
- **Scheduler Stress**: Submitting 1000 tiny jobs spams the scheduler.
- **Management Nightmare**: You have 1000 Job IDs to track/cancel.
- **Fair Share**: You might hog the queue slots.

## Strategy 2: The "Naive" Way (Backgrounding `&`)
You might try to run them all in *one* job using the `&` operator.

```bash
#!/bin/bash
#SBATCH --cpus-per-task=20
...
for file in 01_data/*.fastq; do
    ./process.sh $file &
done
wait
```

**Why is this risky?**
- **No Load Balancing**: If you have 100 files and 20 CPUs, this launches 100 processes at once! You will crash the node (OOM).
- **Complex Logic**: You have to write complex bash to manage "batches" of 20.

## Strategy 3: The "Better" Way (GNU Parallel)
GNU Parallel is a tool designed exactly for this. It manages the queue of tasks *inside* your single Slurm job.

### Activity: Using GNU Parallel
Let's process all 20 files in **one** Slurm job, running **4 at a time**.

Create `00_scripts/03_gnu_parallel.slurm`:

```bash
#!/bin/bash
#SBATCH --job-name=gnu_parallel
#SBATCH --time=00:05:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4      # We want to run 4 tasks at once
#SBATCH --mem=1G               # 4 tasks * ~100MB each + overhead
#SBATCH --output=logs/%x_%j.out

# Load GNU Parallel (check your cluster's module name)
module load parallel || true

# Define the command to run
# {1} is the placeholder for the input file
# {1/.} gets the basename without extension (e.g., sample_00)
CMD="./00_scripts/process_sample.sh {1} 01_data 5"

# Run parallel
# -j $SLURM_CPUS_PER_TASK : Run as many jobs as we requested CPUs (4)
ls 01_data/*.fastq | parallel -j $SLURM_CPUS_PER_TASK "$CMD"
```

Submit it:
```bash
sbatch 00_scripts/03_gnu_parallel.slurm
```

**What happens?**
1. Slurm gives you 4 CPUs.
2. `ls` lists 20 files.
3. `parallel` starts the first 4.
4. As soon as one finishes, `parallel` starts the next one.
5. It keeps 4 running until all 20 are done.

**Pros:**
- One Job ID.
- Efficient packing of short tasks.
- No scheduler spam.

**Cons:**
- If the job dies (time limit), you have to figure out which files finished.
- All output goes to one log file (unless you redirect carefully).
