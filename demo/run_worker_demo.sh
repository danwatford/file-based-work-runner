#!/bin/bash
#
# Runs a demonstration of the file_based_work_runner.sh script.
#
##########################################################################

function main() {
	# Determine the directory containing this script. file_based_work_runner.sh is assumed to be in the parent directory.
	local script_dir=$(dirname $0)
	local work_runner="$script_dir/../file_based_work_runner.sh"
	local worker_demo="$script_dir/worker_demo.sh"
	local work_area="$script_dir/test-work-dir"
	
	# Create the input directory and populate with work files.
	local input_dir="$work_area/input"
	mkdir --parents "$input_dir"
	local -i i=50
	while [[ $i -gt 0 ]]; do
		touch $(printf "$input_dir/input-%02d", $i)
		((i--))
	done
	
	# Run the work runner, using 3 workers and the worker_demo command.
	# For each work file, the worker_demo will decide to randomly suceed or fail, writing to stdout or stderr as appropriate.
	# Based on the success or failure of worker_demo, file_based_work_runner.sh will then move the work file to
	# the worker's completed or failed directory.
	"$work_runner" -w "$work_area" -l 3 -c "$worker_demo"
}

main "$@"