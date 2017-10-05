#!/bin/bash
#
# Launches worker processes to consume work described by multiple input files in an input directory.
#
# See usage() for more information.
################################################################################

declare WORK_AREA_PATH=""
declare INPUT_AREA_PATH=""
declare WORKER_NAME_PREFIX="worker"
declare -i WORKER_ID_FIRST=1
declare -i WORKER_ID_LAST=1
declare WORKER_EXECUTABLE_PATH
declare CONTROL_PATH
declare LOG_PATH

function main() {
	local -i wid=$WORKER_ID_FIRST
	
	parseCommandLine "$@"

	mkdir --parents "$CONTROL_PATH"
	mkdir --parents "$LOG_PATH"
	
	# Remove any control files from previous runs.
	rm "$CONTROL_PATH"/stop 2>/dev/null
	
	# Launch a worker for every configured worker id.
	while [[ $wid -le $WORKER_ID_LAST ]]; do
		launchWorker $wid
		wid=$((wid + 1))
	done
	
	# Wait for all workers to finish.
	wait
}

##########################################
# Prepare required directories and launch a worker process.
#
# $1 - Worker ID (integer)
function launchWorker() {
	local -i wid=$1
	local worker_name=$(printf "$WORKER_NAME_PREFIX-%02d" $wid)

	# Create directories for use by the worker.
	local worker_working_path="$WORK_AREA_PATH/$worker_name-working"
	local worker_complete_path="$WORK_AREA_PATH/$worker_name-complete"
	local worker_failed_path="$WORK_AREA_PATH/$worker_name-failed"
	mkdir --parents "$worker_working_path"
	mkdir --parents "$worker_complete_path"
	mkdir --parents "$worker_failed_path"
	
	# Run the worker as a child process.
	echo launching worker: $worker_name
	runWorker "$worker_name" "$worker_working_path" "$worker_complete_path" "$worker_failed_path" &
}

##########################################
# Performs functions to mange the work to be passed to the worker command.
#
# $1 - Worker name.
# $2 - Working directory.
# $3 - Complete directory.
# $4 - Failed directory.
function runWorker() {
	local worker_name="$1"
	local working_path="$2"
	local complete_path="$3"
	local failed_path="$4"
	
	local -i count=0
	
	while workAvailable "$working_path"; do
		if shouldStop; then
			echo "$worker_name: stopping"
			exit 0
		fi

		local current_file=$(getCurrentWork "$working_path")
		if [[ -n $current_file ]]; then
			(( count++ ))
			echo "$worker_name: ProcessingCount=$count;ProcessingFile=$current_file"
			
			if runWorkerCommand "$worker_name" "$current_file"; then
				mv "$current_file" "$complete_path"
			else
				mv "$current_file" "$failed_path"
			fi
		else
			echo "$worker_name: Capturing work."
			captureWork "$working_path"
		fi
	done
}

##########################################
# Execute the worker's command.
#
# $1 - Worker name.
# $2 - Work file.
function runWorkerCommand() {
	local worker_name="$1"
	local working_file="$2"

	local log_stdout="$LOG_PATH/$worker_name.out"
	local log_stderr="$LOG_PATH/$worker_name.err"

	# Launch the worker command, appending stdout and stderr to log files.
	"$WORKER_EXECUTABLE_PATH" "$working_file" 1>>"$log_stdout" 2>>"$log_stderr"
}

##########################################
# Determine if any new or current work is available for the worker.
#
# $1 - Path to directory which holds the worker's current work file.
function workAvailable() {
	local working_path="$1"
	[[ -n $(getCurrentWork "$working_path") || $(newWorkCount) > 0 ]]
}

##########################################
# Echo the number of new work files available in the input directory.
function newWorkCount() {
	find "$INPUT_AREA_PATH" -maxdepth 1 -type f | wc -l
}

##########################################
# Captures a work file from the input directory by moving it to the current work directory.
#
# $1 - Path to directory which holds the worker's current work file.
function captureWork() {
	local working_path="$1"

	ls -t "$INPUT_AREA_PATH" | while read work_file; do
		mv "$INPUT_AREA_PATH"/"$work_file" "$working_path" 2>/dev/null && return 0
	done
}

##########################################
# Returns the path to any current work file.
#
# $1 - Path to directory which holds the worker's current work file.
function getCurrentWork() {
	local working_path="$1"
	find "$working_path" -maxdepth 1 -type f | head -1
}

##########################################
# Tests whether processing should stop.
function shouldStop() {
	[[ -f "$CONTROL_PATH"/stop ]]
}

##########################################
# Checks that a directory is writable.
#
# $1 - Path to directory to test.
function testDirWritable() {
	if ! [[ -d "$1" && -w "$1" ]]; then
		echo "Path is not a directory or is not writable: $1" >&2
		exit 1
	fi
}

##########################################
# Output usage information.
function usage() {
	cat << EOF
 usage: file_based_work_runner.sh options
 
 Launches worker processes to consume work described by multiple input files in an input directory.
 
 Each launched worker will move an input file from the input directory to a worker specific work directory, 
 before launching a worker command to perform the work on the file.
 
 The worker command must be executable and accept a single argument which is the path to the file to the work on.
 
 Once work is complete the input file will be moved to worker specific completed or failed directory.

 Each worker will monitor a control directory where the presence of a file named stop will cause the worker
 to stop processing.
 
 OPTIONS:
  -w		Work area path. The path to the directory where the runner can create directories to manage work.
  -i		Path to input directory. Defaults to the input directory under the work area path.
  -n		Worker name prefix.
  -f		First worker id. Defaults to 1.
  -l		Last worker id. Defaults to 1.
  -c		Worker command.
EOF
}

##########################################
# Extract arguments from the command line.
function parseCommandLine() {
	OPTIND=1

	while getopts "h?w:i:n:f:l:c:" opt; do
		case "$opt" in
			h|\?)
				usage
				exit 0
				;;
			w)
				WORK_AREA_PATH="$OPTARG"
				testDirWritable "$WORK_AREA_PATH"
				;;
			i)
				INPUT_AREA_PATH="$OPTARG"
				testDirWritable "$INPUT_AREA_PATH"
				;;
			n)
				WORKER_NAME_PREFIX="$OPTARG"
				;;
			f)
				WORKER_ID_FIRST="$OPTARG"
				;;
			l)
				WORKER_ID_LAST="$OPTARG"
				;;
			c)
				WORKER_EXECUTABLE_PATH="$OPTARG"
				;;
		esac
	done

	if [[ -z "$WORK_AREA_PATH" ]]; then
		echo "No work area path specified." >&2
		exit 1
	fi 
	
	if [[ -z "$INPUT_AREA_PATH" ]]; then
		INPUT_AREA_PATH="$WORK_AREA_PATH/input"
	fi
	
	CONTROL_PATH="$WORK_AREA_PATH/control"
	LOG_PATH="$WORK_AREA_PATH/log"
}

main "$@"
