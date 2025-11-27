# Slurm Efficiency & Parallelism Workshop (2026)

Welcome to the 2026 Slurm Workshop! This 4-hour session is designed to help you move beyond basic job submission and master efficient, scalable computing on the University Cluster.

## Workshop Goals
- Understand how to measure and optimize job efficiency (`seff`).
- Learn when to use **GNU Parallel** vs. **Slurm Job Arrays**.
- Master the syntax for running thousands of jobs without crashing the scheduler.

## Curriculum

### [0. Setup & Prerequisites](./00_setup.md)
Getting connected to the cluster (VSCode OnDemand) and generating the workshop test data.

### [1. Efficiency Basics](./01_efficiency_basics.md)
Stop guessing resources! Learn to benchmark your jobs and request exactly what you need.

### [2. Parallelism Strategies](./02_parallelism_strategies.md)
Why looping `sbatch` is bad, and how to use GNU Parallel to pack short tasks into efficient jobs.

### [3. Slurm Job Arrays](./03_slurm_arrays.md)
The "correct" way to handle batch processing. Syntax, file mapping, and logging.

### [4. Advanced Management](./04_advanced_management.md)
Decision matrices, task grouping, and managing massive workflows.

## Getting Started
1. Clone this repository or copy the files to your cluster workspace.
2. Follow the instructions in [00_setup.md](./00_setup.md) to generate the dummy data.
3. Proceed through the modules in order.
