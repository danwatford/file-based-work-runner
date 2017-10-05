#!/bin/bash
#
# Worker demonstrator to randomly declare a success or failure for an input file.
#
##################################################################################

# $1 - Path to input file.
function main() {
	local -r input_file="$1"
	
	echo "Working on input file: $input_file"
	
	if [[ $((RANDOM % 2)) == 0 ]]; then
		echo "Input file processed successfully: $input_file"
	else
		echo "Input file failed processing: $input_file" >&2
		exit 1
	fi	
}

main "$@"