# testbash

Run unit tests for your bash scripts and libraries.

## Howto

1. Create file(s) with tests instructions (see below) in `tests/` directory with `.sh` suffix(es)
2. Import your dependencies (bash scripts with `.sh` extensions), either in putting them into `dependencies/` directory
and/or giving their path as argument of the script
3. Run `test.sh`

## Usage
```bash
./test.sh [OPTIONS] [SCRIPT...]
```

## Options
```
-l  load dependencies before running tests (useful to test a library)
-d  run in debug mode (uses bash `set -x` command)
-h  print help
```

## Exit codes
- 0: All tests OK
- 1: Usage error
- 2: Failed to load dependencies
- 3: No tests to perform
- 4: Tests failed

## Functions
Be careful none of your tests or dependencies is using variables or functions with `tb_` prefixes.
It is used by testbash and could false results.

### tb_test
Run unit test.

#### Usage
```bash
tb_test [OPTIONS] COMMAND|VALUE
```

#### Options
```
-i, --interactive     interactive mode*
-c, --exit-code CODE  set the exit code the command should return
-r, --return VALUE    set the expected value returned by the command
-v, --value           check value instead of command return**
-n, --name TEXT       specify a name for the test
-q, --quiet           do not print command stdout (useful in interactive mode)
```

\*  interactive mode: use it when you don't need to check command sdtout result and/or to preserve context
    e.g. Use `tb_test -i cd /path` to stay into `/path` directory, or else it will be executed into a different context

\** e.g. `tb_test -r "hello" -v $greetings` checks if variable `$greetings` contains 'hello'

## License
testbash is licensed under the MIT License. See [LICENSE.md](LICENSE.md) for the full license text.

## Credits
Author: Jean Prunneaux [http://jean.prunneaux.com](http://jean.prunneaux.com)
