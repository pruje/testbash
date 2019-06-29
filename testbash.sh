#!/bin/bash

########################################################
#                                                      #
#  Unit tests for bash scripts                         #
#                                                      #
#  Author: Jean Prunneaux (http://jean.prunneaux.com)  #
#                                                      #
#  Version 2.4.0 (2019-02-26)                          #
#                                                      #
########################################################

####################
#  INITIALIZATION  #
####################

declare -i tb_tests=0
tb_dependencies=()
tb_success=()
tb_errors=()
tb_current_directory=$(dirname "$0")
tb_tests_directory=$tb_current_directory/tests
tb_dependencies_directory=$tb_current_directory/dependencies


###############
#  FUNCTIONS  #
###############

# Print something if quiet mode disabled
# Usage: tb_echo TEXT
tb_echo() {
	[ "$tb_quietmode" == true ] || echo "$*"
}


# Print script usage
# Usage: tb_usage
tb_usage() {
	echo "Usage: testbash.sh [OPTIONS] [SCRIPT...]"
	echo "Options:"
	echo "  -l  Load dependencies before running tests (useful to test a library)"
	echo "  -s  Stop tests immediately if an error occurs"
	echo "  -e  Enable strict mode (set -e)"
	echo "  -d  Run in debug mode (uses bash set -x command)"
	echo "  -q  Quiet mode"
	echo "  -h  Print this help"
	echo
	echo "Put your unit tests files in the tests/ directory with '.sh' extensions."
}


# Run unit test
# Usage: tb_test [OPTIONS] COMMAND|VALUE
# Options:
#   -i, --interactive     interactive mode
#   -c, --exit-code CODE  set the exit code the command should return
#   -r, --return VALUE    set the expected value returned by the command
#   -v, --value           check value instead of command return
#   -n, --name TEXT       specify a name for the test
#   -q, --quiet           do not print command stdout (useful in interactive mode)
# Exit code: 0: test OK, 1: test NOT OK
tb_test() {

	# remove debug mode to avoid unnecessary log
	$tb_debugmode && set +x

	# default values
	local expected_exitcode=0 expected_result="*" \
	      test_name interactive=false quiet_mode=false test_value=false

	# global quiet mode: force quiet mode
	$tb_quietmode && quiet_mode=true

	tb_tests+=1

	while [ -n "$1" ] ; do
		case $1 in
			-i|--interactive)
				interactive=true
				;;
			-c|--exit-code)
				expected_exitcode=$2
				shift
				;;
			-r|--return)
				expected_result=$2
				shift
				;;
			-v|--value)
				test_value=true
				;;
			-n|--name)
				test_name=$2
				shift
				;;
			-q|--quiet)
				quiet_mode=true
				;;
			*)
				break
				;;
		esac

		# load next argument
		shift
	done

	# set test name
	if [ -z "$test_name" ] ; then
		if $test_value ; then
			test_name="test value"
		else
			test_name=$*
			[ -z "$test_name" ] && test_name="{empty command}"
		fi
	fi

	$test_value && test_name+=" \"$expected_result\" = \"$*\""

	tb_echo
	tb_echo "Run unit test for $test_name..."

	local result exitcode=0 exitcode_ok=false result_ok=false

	# test value mode
	if $test_value ; then
		exitcode=$expected_exitcode
		result=$*
	else
		# or test command
		if $interactive ; then
			# interactive mode

			if $quiet_mode ; then
				# enable debugging
				$tb_debugmode && set -x

				# run command
				"$@" &> /dev/null || exitcode=$?

			else
				# enable debugging
				$tb_debugmode && set -x

				# run command
				"$@" || exitcode=$?
			fi
		else
			if $quiet_mode ; then
				# enable debugging
				$tb_debugmode && set -x

				# run command
				result=$("$@" 2> /dev/null) || exitcode=$?
			else
				# enable debugging
				$tb_debugmode && set -x

				# run command
				result=$("$@") || exitcode=$?
			fi
		fi

		# remove debug mode to avoid unnecessary log
		$tb_debugmode && set +x
	fi

	# test result code
	if [ "$expected_exitcode" == "*" ] ; then
		exitcode_ok=true
	else
		if [ $exitcode == $expected_exitcode ] ; then
			exitcode_ok=true
		fi
	fi

	# test result
	if [ "$expected_result" == "*" ] ; then
		result_ok=true
	else
		if [ "$result" == "$expected_result" ] ; then
			result_ok=true
		fi
	fi

	local test_file=$(basename "$tb_current_test_file" .sh)

	# if test OK
	if $exitcode_ok && $result_ok ; then
		tb_echo "...Passed"

		# log success
		tb_success+=("$test_file: $test_name")

		# enable debugging
		$tb_debugmode && set -x

		return 0

	else
		tb_echo "...FAILED"

		# log error details
		error_details="$test_file: $test_name"

		if ! $test_value ; then
			error_details+=" (code: $exitcode/$expected_exitcode"
			if [ "$expected_result" != "*" ] ; then
				error_details+=", returned: \"$result\" / \"$expected_result\""
			fi
			error_details+=")"
		fi

		tb_errors+=("$error_details")

		# if stop on error, print final report (and quit)
		$tb_stoponerror && tb_final_report

		# enable debugging
		$tb_debugmode && set -x

		return 1
	fi
}


# Print final report and quit
# Usage: tb_final_report
tb_final_report() {
	tb_echo
	tb_echo "-----------------------------"
	tb_echo

	if [ $tb_tests == 0 ] ; then
		echo "No tests found."
		tb_usage
		exit 3
	fi

	if [ ${#tb_errors[@]} == 0 ] ; then
		echo "All test succeeded!"
	else
		echo "Some tests failed!"
	fi

	if [ ${#tb_success[@]} -gt 0 ] ; then
		echo
		echo "Success: (${#tb_success[@]}/$tb_tests)"
		for tb_i in "${tb_success[@]}" ; do
			echo "   - $tb_i"
		done
	fi
	if [ ${#tb_errors[@]} -gt 0 ] ; then
		echo
		echo "Errors: (${#tb_errors[@]}/$tb_tests)"
		for tb_i in "${tb_errors[@]}" ; do
			echo "   - $tb_i"
		done

		exit 4
	fi

	exit
}


##################
#  MAIN PROGRAM  #
##################

# default options
tb_load_dependencies=false
tb_stoponerror=false
tb_debugmode=false
tb_quietmode=false

# get command line options
while getopts ":lsedqh" tb_opts ; do
	case $tb_opts in
		l)
			tb_load_dependencies=true
			;;
		s)
			tb_stoponerror=true
			;;
		e)
			tb_stoponerror=true
			# enable strict mode
			set -e
			;;
		d)
			tb_debugmode=true
			;;
		q)
			tb_quietmode=true
			;;
		h)
			tb_usage
			exit 0
			;;
		\?)
			tb_usage
			exit 1
			;;
	esac
done

# load dependencies in dependencies/ directory
for tb_d in $(find -L "$tb_dependencies_directory" -name '*.sh' | sort) ; do
	tb_dependencies+=("$tb_d")

	if $tb_load_dependencies ; then
		echo "Loading $tb_d..."
		source "$tb_d"
		if [ $? != 0 ] ; then
			echo "Failed! Please check your file."
			exit 2
		fi
	fi
done

# load dependencies from command line arguments
for tb_d in "${@: OPTIND}" ; do
	if ! [ -f "$tb_d" ] ; then
		echo "ERROR: $tb_d is not a file!"
		exit 1
	fi

	tb_dependencies+=("$tb_d")

	if $tb_load_dependencies ; then
		echo "Loading $tb_d..."
		source "$tb_d"
		if [ $? != 0 ] ; then
			echo "... Failed! Please check your file."
			exit 2
		fi
	fi
done

# no dependencies
if $tb_load_dependencies ; then
	if [ ${#tb_dependencies[@]} == 0 ] ; then
		echo "ERROR: Missing dependencies!"
		tb_usage
		exit 2
	fi
fi

# if no tests directory, error
if ! [ -d "$tb_tests_directory" ] ; then
	tb_usage
	exit 3
fi

echo "Running unit tests..."

# load test files
for tb_testfile in $(find -L "$tb_tests_directory" -name '*.sh' | sort) ; do
	tb_echo
	tb_echo "-----------------------------"
	tb_echo
	tb_echo "Running tests from '$(basename $tb_testfile)':"

	tb_current_test_file=$tb_testfile
	tb_current_test_directory=$(dirname "$tb_testfile")

	# enable debug mode
	$tb_debugmode && set -x

	# run test file
	tb_testfile_result=0
	source "$tb_testfile" || tb_testfile_result=$?

	# remove debug mode to avoid unnecessary log
	$tb_debugmode && set +x

	if [ $tb_testfile_result != 0 ] ; then
		tb_errors+=("$tb_testfile returned error ($tb_testfile_result)")
		break
	fi
done

tb_final_report
