# testbash example file
#
# Copy this file into tests/ directory to test it


# test a bad command: should return 127
tb_test -c 127 badCommandThatDoesntExists


# test a basic command: should print "Hello" and return 0
tb_test -i echo "Hello"


# test variable content
username="me"
tb_test -r "me" -v $username


# compare numbers: 1 is NOT greater than 2 (return 1)
i=1
tb_test --name "is $i > 2" -c 1 [ $i -gt 2 ]


# test return of a function
get_root_path() {
  echo "/root"
}
tb_test -r "/root" get_root_path
