# Module 1: The Efficiency Mindset & Benchmarking

**Goal**: How to stop guessing resources and learn to measure what your jobs actually need.

## The "Blind Guess" Problem
When you submit a job, you have to request:
- Time (`--time`)
- Memory (`--mem`)
- CPUs (`--cpus-per-task`)

**What happens if you guess wrong?**
1. **Guess too low**: Job killed by Slurm (OOM - Out Of Memory, or Time Limit).
2. **Guess too high**: 
   - You wait longer in the queue (harder to find a big hole in the schedule).
   - You waste resources that others could use.
   - Your "Fair Share" score drops, making future jobs wait longer.

---

## Activity 1: The Baseline Job
Let's run a single job and see how efficient we are.

Create a submission script `00_scripts/01_baseline.slurm`:

```bash
#!/bin/bash
#SBATCH --job-name=baseline_test
#SBATCH --time=00:10:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

# Load any modules if needed (none for our dummy script)

# Run our dummy processor on one file
# We are adding a 30-second sleep to simulate "work"
./00_scripts/process_sample.sh 01_data/sample_00.fastq 01_data 30
```

Submit it:
```bash
sbatch 00_scripts/01_baseline.slurm
```

Wait for it to finish (check with `squeue -u $USER`).

---

## Tools for Measuring Efficiency

### 1. `seff` (Slurm Efficiency)
Once the job completes, get its Job ID and run:

```bash
seff <JOB_ID>
```

**Example Output:**
```text
Job ID: 123456
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 1
CPU Utilized: 00:00:00
CPU Efficiency: 0.00% of 00:10:00 core-walltime
Job Wall-clock time: 00:00:31
Memory Utilized: 0.00 MB
Memory Efficiency: 0.00% of 4.00 GB
```

**Analysis:**
- We requested **10 minutes**, used **31 seconds**.
- We requested **4 GB RAM**, used **~0 MB**.
- **Conclusion**: We are vastly over-requesting.

### 2. `/usr/bin/time -v`
For more detailed (and real-time-ish) stats *inside* the job output, put `/usr/bin/time -v` before your command.

Modify `00_scripts/01_baseline.slurm`:
```bash
/usr/bin/time -v ./00_scripts/process_sample.sh 01_data/sample_00.fastq 01_data 30
```

Submit again and check the output file (`cat logs/baseline_test_<jobid>.out`). Look for:
- `Maximum resident set size (kbytes)`: Peak RAM usage.
- `Percent of CPU this job got`: CPU utilization.

---

## Optimizing the Request
Now that we know the job takes ~30s and minimal RAM, we can tighten our request.

**Rule of Thumb**: Request **20-30% more** than the maximum you observed, to be safe.

**Optimized Script** (`00_scripts/02_optimized.slurm`):
```bash
#!/bin/bash
#SBATCH --job-name=optimized
#SBATCH --time=00:02:00        # 2 minutes (plenty for a 30s job)
#SBATCH --mem=100M             # 100MB (plenty for a tiny script)
#SBATCH --cpus-per-task=1
#SBATCH --output=logs/%x_%j.out

./00_scripts/process_sample.sh 01_data/sample_00.fastq 01_data 30
```

### Why this matters for Arrays
If you run 1 job, wasting 4GB RAM is fine.
If you run **1,000 jobs** (Array), wasting 4GB each = **4 Terabytes** of wasted RAM reservation. Slurm will never be able to schedule all that, and you will wait forever.

**Key Takeaway**: Always benchmark a *single* task before launching an array!
