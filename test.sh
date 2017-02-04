#!/bin/bash

########################################################
#                                                      #
#  Unit tests for bash scripts                         #
#                                                      #
#  Author: Jean Prunneaux (http://jean.prunneaux.com)  #
#                                                      #
#  Version 2.1.0 (2017-02-04)                          #
#                                                      #
########################################################

####################
#  INITIALIZATION  #
####################

declare -i tb_tests=0
tb_dependencies=()
tb_success=()
tb_errors=()
tb_current_directory="$(dirname "$0")"
tb_tests_directory="$tb_current_directory/tests/"
tb_dependencies_directory="$tb_current_directory/dependencies/"


###############
#  FUNCTIONS  #
###############

# Print script usage
# Usage: tb_usage
tb_usage() {
	echo "Usage: $0 [OPTIONS] [SCRIPT...]"
	echo "Options:"
	echo "  -l  load dependencies before running tests (useful to test a library)"
	echo "  -d  run in debug mode (uses bash set -x command)"
	echo "  -h  print help"
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
	if $tb_debugmode ; then
		set +x
	fi

	# default values
	tb_expected_code=0
	tb_expected_result="*"
	tb_interactive=false
	tb_testname=""
	tb_quietmode=false
	tb_testvalue=false

	tb_tests+=1

	while true ; do
		case "$1" in
			-i|--interactive)
				tb_interactive=true
				shift
				;;
			-c|--exit-code)
				tb_expected_code="$2"
				shift 2
				;;
			-r|--return)
				tb_expected_result="$2"
				shift 2
				;;
			-v|--value)
				tb_testvalue=true
				shift
				;;
			-n|--name)
				tb_testname="$2"
				shift 2
				;;
			-q|--quiet)
				tb_quietmode=true
				shift
				;;
			*)
				break
				;;
		esac
	done

	# set test name
	if [ -z "$tb_testname" ] ; then
		if $tb_testvalue ; then
			tb_testname="$*=$tb_expected_result"
		else
			tb_testname="$*"

			if [ -z "$tb_testname" ] ; then
				tb_testname="{empty command}"
			fi
		fi
	fi

	echo
	echo "Run unit test for $tb_testname..."

	tb_result=""
	tb_codeok=false
	tb_resok=false

	# test value mode
	if $tb_testvalue ; then
		tb_res_code=$tb_expected_code
		tb_result="$*"
	else
		# or test command
		if $tb_interactive ; then
			# interactive mode

			if $tb_quietmode ; then
				# enable debugging
				if $tb_debugmode ; then
					set -x
				fi

				# run command
				$* &> /dev/null

			else
				# enable debugging
				if $tb_debugmode ; then
					set -x
				fi

				# run command
				$*
			fi
		else
			if $tb_quietmode ; then
				# enable debugging
				if $tb_debugmode ; then
					set -x
				fi

				# run command
				tb_result="$($* &> /dev/null)"
			else
				# enable debugging
				if $tb_debugmode ; then
					set -x
				fi

				# run command
				tb_result="$($*)"
			fi
		fi

		# get command result
		tb_res_code=$?

		# remove debug mode to avoid unnecessary log
		if $tb_debugmode ; then
			set +x
		fi
	fi

	# test result code
	if [ "$tb_expected_code" == "*" ] ; then
		tb_codeok=true
	else
		if [ $tb_res_code == $tb_expected_code ] ; then
			tb_codeok=true
		fi
	fi

	# test result
	if [ "$tb_expected_result" == "*" ] ; then
		tb_resok=true
	else
		if [ "$tb_result" == "$tb_expected_result" ] ; then
			tb_resok=true
		fi
	fi

	# if test OK
	if $tb_codeok && $tb_resok ; then
		echo "...Passed"

		# log success
		tb_success+=("$tb_testname")

		# enable debugging
		if $tb_debugmode ; then
			set -x
		fi

		return

	else
		echo "...FAILED"

		# log error details
		if $tb_testvalue ; then
			tb_txterror="$tb_testname"
		else
			tb_txterror="$tb_testname (code: $tb_res_code/$tb_expected_code"
			if [ "$tb_expected_result" != "*" ] ; then
				tb_txterror+=", returned: $tb_result/$tb_expected_result"
			fi
			tb_txterror+=")"
		fi

		tb_errors+=("$tb_txterror")

		# enable debugging
		if $tb_debugmode ; then
			set -x
		fi

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
		\?) echo "ERROR: '"$OPTARG"' option does not exist."
		    tb_usage
		    exit 1
		    ;;
	esac
done

# load dependencies before run
if $tb_load_dependencies ; then
	echo "Load dependencies..."
fi

# load dependencies in dependencies/ directory
for tb_d in $(find "$tb_dependencies_directory" -name '*.sh' | sort) ; do
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
for tb_d in ${@: OPTIND} ; do
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
for tb_testfile in $(find "$tb_tests_directory" -name '*.sh' | sort) ; do
	echo
	echo "-----------------------------"
	echo
	echo "Running tests from '$(basename $tb_testfile)':"

	# enable debug mode
	if $tb_debugmode ; then
		set -x
	fi

	# run test file
	source "$tb_testfile"
	testfile_res=$?

	# remove debug mode to avoid unnecessary log
	if $tb_debugmode ; then
		set +x
	fi

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
	echo "Test succeeded!"
else
	echo "Some tests failed!"
fi

if [ ${#tb_success[@]} -gt 0 ] ; then
	echo
	echo "Success: (${#tb_success[@]}/$tb_tests)"
	for ((tb_i=0; tb_i<${#tb_success[@]}; tb_i++)) ; do
		echo "   - ${tb_success[$tb_i]}"
	done
fi
if [ ${#tb_errors[@]} -gt 0 ] ; then
	echo
	echo "Errors: (${#tb_errors[@]}/$tb_tests)"
	for ((tb_i=0; tb_i<${#tb_errors[@]}; tb_i++)) ; do
		echo "   - ${tb_errors[$tb_i]}"
	done

	exit 4
fi
