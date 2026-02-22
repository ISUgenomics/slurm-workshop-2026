# Module 5: Choosing the Right Approach

**Goal**: A practical guide to deciding between simple loops, GNU Parallel, and Slurm arrays.

## Quick Reference: When to Use What

```
                    ┌─────────────────────────────────────────────┐
                    │         Do I have multiple tasks?           │
                    └───────────────────┬─────────────────────────┘
                                        │
                            ┌───────────┴───────────┐
                            │                       │
                          ┌─▼─┐                   ┌─▼─┐
                          │No │                   │Yes│
                          └─┬─┘                   └─┬─┘
                            │                       │
                            ▼                       ▼
                    ┌───────────────┐     ┌─────────────────────────┐
                    │ Single sbatch │     │ How long is each task?  │
                    │    (done!)    │     └───────────┬─────────────┘
                    └───────────────┘         ┌───────┴────────┐
                                              │                │
                                     ┌────────▼──────┐  ┌──────▼─────────┐
                                     │ < 15 minutes  │  │  > 15 minutes  │
                                     └───────┬───────┘  └───────┬────────┘
                                             │                  │
                                             ▼                  ▼
                                    ┌────────────────┐  ┌───────────────────┐
                                    │  GNU Parallel  │  │  Slurm Job Array  │
                                    │    (pack)      │  │    (scatter)      │
                                    └────────────────┘  └───────────────────┘
```

---

## The Three Approaches

### 1. Sequential Loops (Baseline)

```bash
for file in 01_data/*.fastq; do
    ./process.sh "$file"
done
```

| Pros | Cons |
| :--- | :--- |
| Simple to write | Painfully slow |
| Easy to debug | No parallelism |
| Fine for 2-3 tasks | Doesn't use HPC resources |

**Use when**: Testing your script on a single file, or you have very few tasks and no time pressure.

---

### 2. Loop with `sbatch` (DON'T DO THIS)

```bash
# ⚠️ BAD PRACTICE!
for file in 01_data/*.fastq; do
    sbatch process.slurm "$file"
done
```

| Pros | Cons |
| :--- | :--- |
| Tasks run in parallel | Scheduler spam (thousands of jobs) |
| | Nightmare to track Job IDs |
| | Destroys your Fair Share |
| | Admins will contact you |

**Use when**: Almost never. This is the "wrong" way that we're trying to avoid.

---

### 3. GNU Parallel (Task Packing)

```bash
#SBATCH --cpus-per-task=8
ls 01_data/*.fastq | parallel -j $SLURM_CPUS_PER_TASK "./process.sh {1}"
```

| Pros | Cons |
| :--- | :--- |
| One job = one Job ID | All output in one log (messy) |
| Efficient for short tasks | If job dies, partial progress lost |
| Automatic load balancing | Runs on single node only |
| Low scheduler overhead | Must manually track which tasks finished |

**Use when**: 
- You have many (**50+**) short tasks (**< 15 minutes** each)
- Tasks are I/O-light
- Quick-and-dirty batch processing

---

### 4. Slurm Job Arrays (Task Scattering)

```bash
#SBATCH --array=0-99
INPUT_FILE=${FILES[$SLURM_ARRAY_TASK_ID]}
./process.sh "$INPUT_FILE"
```

| Pros | Cons |
| :--- | :--- |
| Separate log per task | Scheduler overhead per task |
| Independent failures | Not ideal for < 5 minute tasks |
| Easy re-run of failed indices | Requires file-to-index mapping |
| Can spread across cluster | |

**Use when**: 
- Tasks run **15+ minutes** each
- You need independent logging
- You want easy failure recovery

---

## Decision Matrix

| Task Duration | Number of Tasks | Best Strategy |
| :---: | :---: | :--- |
| < 1 minute | Any | **GNU Parallel** (or reconsider if you need HPC) |
| 1-15 minutes | < 50 | **GNU Parallel** in a single job |
| 1-15 minutes | 50-1000 | **GNU Parallel** split into multiple jobs |
| 15 min - 4 hours | < 500 | **Slurm Job Array** |
| 15 min - 4 hours | 500+ | **Slurm Job Array** with `%` throttle |
| 4+ hours | Any | **Slurm Job Array** (consider checkpointing) |
| 1000s of short tasks | Any | **Task Grouping** (bundle tasks into array elements) |

---

## Feature Comparison

| Feature | Loop + sbatch | GNU Parallel | Slurm Array |
| :--- | :---: | :---: | :---: |
| **Single Job ID** | ❌ | ✅ | ✅ |
| **Scheduler Friendly** | ❌ | ✅ | ✅ |
| **Separate Logs** | ✅ | ❌ | ✅ |
| **Independent Failures** | ✅ | ❌ | ✅ |
| **Multi-Node** | ✅ | ❌ | ✅ |
| **Easy Retry** | ❌ | ❌ | ✅ |
| **Low Overhead** | ❌ | ✅ | ❌ |

---

## Real-World Scenarios

### Scenario 1: Image Thumbnails
> 5,000 images, each takes 3 seconds to resize.

**Best choice**: **GNU Parallel**  
- Tasks are too short for arrays (scheduler overhead would dominate)
- Pack into a single 2-hour job running 16 at a time

```bash
#SBATCH --cpus-per-task=16
#SBATCH --time=02:00:00
ls images/*.jpg | parallel -j $SLURM_CPUS_PER_TASK "convert {} -resize 100x100 thumbs/{/}"
```

---

### Scenario 2: RNA-seq Alignment
> 48 samples, each takes 2 hours, uses 8 CPUs and 32GB RAM.

**Best choice**: **Slurm Job Array**  
- Long-running tasks benefit from independent logging
- Each sample may have different failure modes
- Easy to re-run failed samples

```bash
#SBATCH --array=0-47%10
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=03:00:00
```

---

### Scenario 3: Parameter Sweep
> 10,000 simulations, each takes 30 seconds.

**Best choice**: **Task Grouping with GNU Parallel**  
- 10,000 array tasks would overwhelm the scheduler
- Bundle 100 simulations per array task (100 array elements)

```bash
#SBATCH --array=0-99
#SBATCH --cpus-per-task=8

START=$((SLURM_ARRAY_TASK_ID * 100))
END=$((START + 99))

seq $START $END | parallel -j $SLURM_CPUS_PER_TASK "./simulate.sh {}"
```

---

## Common Mistakes to Avoid

1. **Over-requesting resources in arrays**
   - 1000 tasks × 4GB each = 4TB reserved. Benchmark first!

2. **No concurrency limit on large arrays**
   - Always use `%N` for arrays over 100 tasks: `--array=0-999%50`

3. **Using arrays for < 5 minute tasks**
   - Scheduler overhead eats your time. Use GNU Parallel.

4. **Skipping the benchmarking step**
   - Always run `seff` on a single task before launching at scale.

5. **No error checking in scripts**
   - Always validate inputs at the start of your script.

---

## Quick Decision Checklist

Before running at scale, ask yourself:

- [ ] Have I benchmarked a single task with `seff`?
- [ ] Is my resource request tight (with ~20% buffer)?
- [ ] Am I using the right strategy for my task duration?
- [ ] If using arrays > 100 tasks, do I have a `%` limit?
- [ ] Do my log files use unique names (`%A_%a` for arrays)?
- [ ] Have I tested on a small subset first?

---

## Summary

| If your tasks are... | Use... |
| :--- | :--- |
| Very short (< 1 min) | GNU Parallel |
| Short (1-15 min) | GNU Parallel |
| Medium (15 min - 4 hrs) | Slurm Array |
| Long (4+ hours) | Slurm Array with checkpointing |
| Massive (10,000+) | Task Grouping into Arrays |

**Remember**: The goal is to use HPC resources efficiently while keeping the scheduler happy. When in doubt, start small and scale up!
