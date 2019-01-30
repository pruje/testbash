#!/bin/bash

########################################################
#                                                      #
#  Unit tests for bash scripts                         #
#                                                      #
#  Author: Jean Prunneaux (http://jean.prunneaux.com)  #
#                                                      #
#  Version 2.3.0 (2019-01-30)                          #
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

# Print script usage
# Usage: tb_usage
tb_usage() {
	echo "Usage: testbash.sh [OPTIONS] [SCRIPT...]"
	echo "Options:"
	echo "  -l  Load dependencies before running tests (useful to test a library)"
	echo "  -d  Run in debug mode (uses bash set -x command)"
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
			test_name="\"$expected_result\" = \"$*\""
		else
			test_name=$*

			if [ -z "$test_name" ] ; then
				test_name="{empty command}"
			fi
		fi
	fi

	echo
	echo "Run unit test for $test_name..."

	local result exitcode_ok=false result_ok=false

	# test value mode
	if $test_value ; then
		exitcode=$expected_exitcode
		result=$*
	else
		# get command
		tb_cmd=()
		while [ -n "$1" ] ; do
			tb_cmd+=("$1")
			shift
		done

		# or test command
		if $interactive ; then
			# interactive mode

			if $quiet_mode ; then
				# enable debugging
				$tb_debugmode && set -x

				# run command
				"${tb_cmd[@]}" &> /dev/null

			else
				# enable debugging
				$tb_debugmode && set -x

				# run command
				"${tb_cmd[@]}"
			fi
		else
			if $quiet_mode ; then
				# enable debugging
				$tb_debugmode && set -x

				# run command
				result=$("${tb_cmd[@]}" &> /dev/null)
			else
				# enable debugging
				$tb_debugmode && set -x

				# run command
				result=$("${tb_cmd[@]}")
			fi
		fi

		# get command result
		exitcode=$?

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
		echo "...Passed"

		# log success
		tb_success+=("$test_file: $test_name")

		# enable debugging
		$tb_debugmode && set -x

		return 0

	else
		echo "...FAILED"

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

		# enable debugging
		$tb_debugmode && set -x

		return 1
	fi
}


##################
#  MAIN PROGRAM  #
##################

# default options
tb_debugmode=false
tb_load_dependencies=false

# get command line options
while getopts ":ldh" tb_opts ; do
	case $tb_opts in
		l) tb_load_dependencies=true
		   ;;
		d) tb_debugmode=true
		   ;;
		h) tb_usage
		   exit 0
		   ;;
		\?) echo "ERROR: '$OPTARG' option does not exist."
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
	echo
	echo "-----------------------------"
	echo
	echo "Running tests from '$(basename $tb_testfile)':"

	tb_current_test_file=$tb_testfile
	tb_current_test_directory=$(dirname "$tb_testfile")

	# enable debug mode
	$tb_debugmode && set -x

	# run test file
	source "$tb_testfile"
	testfile_res=$?

	# remove debug mode to avoid unnecessary log
	$tb_debugmode && set +x

	if [ $testfile_res != 0 ] ; then
		tb_errors+=("$tb_testfile returned error ($testfile_res)")
		break
	fi
done


##################
#  FINAL REPORT  #
##################

echo
echo "-----------------------------"
echo

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
