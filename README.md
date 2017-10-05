# File Based Work Runner

A script to launch child processes to operate on work items defined by files.

The File Based Work Runner is a bash script that will launch multiple child processes.
These child processes will:
- Move a work item (file) from the input directory to a child process specific work directory, claiming the work item.
- Call a worker command to operate on the work item.
- Based on the exit code of the worker command, move the work item to a child process specific complete or failed directory.
- Loop until all work items have been processed.

In addition child processes will monitor a control directory for a file name stop and will terminate after any
current processing completes.

Child processes redirect stdout and stderr to child process specific log files.

# Demo

The demo directory contains the script run_worker_demo.sh which will create a number of input files and then
execute file_based_work_runner.sh to process the input files across a number of child processes.
