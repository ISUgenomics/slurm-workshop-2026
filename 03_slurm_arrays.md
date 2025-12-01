# Module 3: Slurm Job Arrays

**Goal**: The "Correct" way to handle independent tasks at scale.

## What is a Job Array?
A Job Array is a single job submission that spawns multiple "tasks".
- **One Job ID** (Master ID), but many **Array Indices**.
- Example: `123456_0`, `123456_1`, `123456_2`...
- Each task runs the *same script* but with a different `$SLURM_ARRAY_TASK_ID`.

## Why use Arrays?
- **Independent**: If Task 5 fails, Task 6 still runs.
- **Throttle**: You can limit how many run at once (`%10`).
- **Logs**: Each task gets its own output file (`%A_%a.out`).
- **Retry**: You can re-submit *only* the failed indices.

---

## Activity: The Array Job
Let's process our 20 files using an array.

### Step 1: Mapping IDs to Files
The variable `$SLURM_ARRAY_TASK_ID` is just a number (0, 1, 2...). We need to turn "0" into "sample_00.fastq".

Create `00_scripts/04_array.slurm`:

```bash
#!/bin/bash
#SBATCH --job-name=array_test
#SBATCH --time=00:02:00
#SBATCH --mem=200M             # Memory PER TASK (not total!)
#SBATCH --cpus-per-task=1      # CPUs PER TASK
#SBATCH --array=0-19           # Run indices 0 through 19 (20 tasks)
#SBATCH --output=logs/%x_%A_%a.out  # %A=MasterID, %a=Index

# 1. Create a list of files (bash array)
FILES=(01_data/*.fastq)

# 2. Get the file for this task ID
# SLURM_ARRAY_TASK_ID is set automatically by Slurm
INPUT_FILE=${FILES[$SLURM_ARRAY_TASK_ID]}

# Check if file exists (good practice)
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Could not find file for index $SLURM_ARRAY_TASK_ID"
    exit 1
fi

echo "This is Array Task $SLURM_ARRAY_TASK_ID processing $INPUT_FILE"

# 3. Run the command
./00_scripts/process_sample.sh "$INPUT_FILE" 01_data 10
```

### Step 2: Submit
```bash
sbatch 00_scripts/04_array.slurm
```

### Step 3: Monitor
Watch the queue:
```bash
squeue -u $USER
```
You will see one line like `123456_[0-19]` (PENDING) or expanded lines for running tasks.

### Step 4: Check Logs
Look at the logs directory:
```bash
ls logs/array_test*
```
You should see 20 separate log files. This makes debugging easy! If file 13 failed, you just check `..._13.out`.

---

## Advanced Mapping (Non-Sequential Files)
What if your files aren't nicely named or you have a text list of filenames?

**Method: `sed`**
If you have a file `file_list.txt` with one filename per line:

```bash
# Get the Nth line from the file
INPUT_FILE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" file_list.txt)
```
(Note: `sed` is 1-indexed, so you might need `--array=1-20`).

---

## Comparison: GNU Parallel vs. Arrays

| Feature | GNU Parallel | Slurm Arrays |
| :--- | :--- | :--- |
| **Submission** | 1 Job | 1 Job (many tasks) |
| **Queue** | Occupies 1 node (usually) | Can scatter across cluster |
| **Logs** | Combined (messy) | Separate (clean) |
| **Failure** | Job fails | Individual tasks fail |
| **Best For** | Many tiny tasks (< 1 min) | Medium/Large tasks (> 10 min) |
