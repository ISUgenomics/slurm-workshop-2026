# Module 4: Advanced Management & Decision Making

**Goal**: Become a Slurm Power User. Make smart choices.

## The Efficiency Trap: "Too Many Tiny Jobs"
You have 10,000 files. Each takes 10 seconds to process.
You submit an Array: `#SBATCH --array=0-9999`.

**What happens?**
- The scheduler has to track 10,000 start/stop events.
- The overhead of starting a job might be 5 seconds. You are spending 33% of time just booting!
- Admins will be angry.

**Solution: Task Grouping**
Process *multiple* files in one array task.
Instead of 1 file per task, do 10 or 100.

```bash
#SBATCH --array=0-99
# ...
# Inside the script, handle a "chunk" of files based on ID
```
(This requires slightly more complex bash scripting, or using tools like `launcher` or `hyperqueue`, but for now, just know that **Jobs < 5 mins are bad candidates for Arrays**).

---

## Limiting Concurrency (`%`)
You have 1,000 big jobs. You don't want to hog the entire cluster.
Use the `%` operator in the array definition.

```bash
#SBATCH --array=0-999%50
```
This means: "Run 1000 tasks, but **only 50 at a time**."
As one finishes, another starts. This is polite and keeps your Fair Share reasonable.

---

## Handling Failures: The "Swiss Cheese" Array
You ran 100 jobs.
- Tasks 0-45: Success
- Task 46: FAILED (Network blip)
- Tasks 47-88: Success
- Task 89: FAILED (Bad data)
- ...

You don't want to re-run everything.
Check which IDs failed (look at logs or `sacct`).
Then submit **only the holes**:

```bash
sbatch --array=46,89,92-95 00_scripts/04_array.slurm
```
Slurm allows comma-separated lists and ranges!

---

## The Decision Matrix: GNU Parallel vs. Slurm Arrays

How do you choose? Use this simple rule of thumb based on **Task Duration** and **Quantity**.

| Scenario | Recommended Strategy | Why? |
| :--- | :--- | :--- |
| **Few long tasks** (e.g., 10 files, 2 hours each) | **Slurm Job Array** | Easy to manage, each gets full resources, independent logs. |
| **Many short tasks** (e.g., 1000 files, 5 mins each) | **GNU Parallel** | Packs them into fewer jobs to avoid scheduler overhead. |
| **Massive quantity** (e.g., 100,000 tasks) | **Task Grouping** | Arrays of Arrays or Workflow Managers (Nextflow) are needed. |
| **Complex dependencies** (Job B needs Job A) | **Workflow Manager** | Slurm dependencies are painful for complex graphs. |

### Decision Flowchart

1. **Is it a single, massive parallel program (MPI)?**
   - -> `sbatch` with `--nodes=N --ntasks=M` (Not covered today).

2. **Do I have many independent files/parameters?**
   - **Yes.**
     - **Are the tasks short (< 15 mins)?**
       - -> **GNU Parallel** (Pack them into 1-hour chunks).
     - **Are the tasks medium/long (> 1 hour)?**
       - -> **Slurm Job Array**.
     - **Are there millions of them?**
       - -> **Task Grouping** or Workflow Managers (Nextflow/Snakemake).

---

## Final Challenge
**Scenario**:
You have a folder `raw_data/` with 50 `.csv` files.
You have a script `analyze.py` that takes 1 hour per file and uses 4GB RAM.
You want to finish by tomorrow morning.

**Question**:
1. Write the `#SBATCH` header for this job.
2. Which strategy do you choose?

<details>
<summary>Answer</summary>

**Strategy**: Slurm Job Array.
- 1 hour is perfect for an array task.
- 50 files is a manageable array size.

**Header**:
```bash
#SBATCH --time=01:10:00        # 1h + buffer
#SBATCH --mem=5G               # 4G + buffer
#SBATCH --cpus-per-task=1
#SBATCH --array=0-49
```
</details>
