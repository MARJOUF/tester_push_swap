# push_swap Tester

A Bash testing script for the **42 / 1337 `push_swap` project**. It helps you check the mandatory part, bonus `checker`, sorting correctness, strategy flags, benchmark output, performance, memory handling, and the coexistence of both executables.

> **Important:** This is an unofficial helper script, not an official 42/1337 evaluator. Passing these tests does not guarantee a perfect evaluation. Always read the project subject and review the code yourself.

## Features

### Mandatory (`push_swap`)
- Checks the required Makefile targets and build behavior.
- Checks that `push_swap` is produced and that a second `make` does not relink it.
- Checks compiler flags `-Wall -Wextra -Werror`.
- Tests invalid arguments: non-numeric input, duplicates, empty arguments, malformed numbers, integer overflow and underflow.
- Tests valid edge values, including `INT_MIN` and `INT_MAX`.
- Tests already-sorted inputs (expects zero instructions).
- Tests `--simple`, `--medium`, `--complex`, `--adaptive`, and the default strategy.
- Checks that the default behavior matches `--adaptive`.
- Validates emitted instructions with an independent reference simulator.
- Tests small, random, sorted, reverse-sorted, and different-disorder inputs.
- Checks the 3-number and 5-number instruction-count guidelines.
- Checks the 100-number and 500-number performance limits from the evaluation sheet.
- Checks benchmark output, operation counts, disorder percentage, strategy information, and that benchmark mode does not change the instructions printed to stdout.

### Bonus (`checker`)
- Checks bonus compilation and Makefile behavior.
- Tests argument errors and malformed instructions.
- Tests whitespace and formatting errors in instruction input.
- Tests `OK` and `KO` cases, including the official evaluation examples.
- Tests all 11 push_swap operations against a reference simulator.
- Runs randomized differential tests.
- Can compare results with an official checker binary if one is available.

### Extra checks
- Runs Valgrind when installed (or macOS `leaks` where available).
- Checks for suspicious external symbols and global/static symbols with `nm` (warnings need manual review).
- Audits required README sections and algorithm/contribution documentation.
- Provides a manual defense checklist for requirements that cannot be reliably automated, such as explaining the algorithms and implementing `--count-only` live.

## Requirements

- Bash
- A Unix-like environment (Linux is recommended; macOS may work with suitable tools)
- `make`
- `awk`, `sed`, `grep`, `find`, `nm`, `stat`, and standard shell utilities
- `shuf` for the official random performance test (usually available on Linux)
- `norminette` for Norminette checks
- `valgrind` for memory checks on Linux; on macOS the script can use `leaks`
- Your project source code and Makefile

Some optional tools are skipped or reported as unavailable if they are not installed. The script uses `timeout` when available, or `gtimeout` as a fallback.

## Installation

Place `tester_detailed_full.sh` in the root of your `push_swap` repository, next to your `Makefile`.

```bash
chmod +x tester_detailed_full.sh
```

Your project should build these executables:

```text
./push_swap
./checker
```

The bonus tests expect the checker executable to be named `checker` and built by:

```bash
make bonus
```

## Usage

Run every test group, including Norminette:

```bash
./tester_detailed_full.sh --only all
```

Show each individual passing test as well as failures:

```bash
./tester_detailed_full.sh --only all --verbose
```

### Select a test stage

```bash
# Mandatory part only
./tester_detailed_full.sh --only mandatory

# Bonus checker only
./tester_detailed_full.sh --only bonus

# Mandatory + bonus + integration tests
./tester_detailed_full.sh --only both

# Norminette only
./tester_detailed_full.sh --only norm
```

`both` runs mandatory, bonus, and integration checks that verify the two executables can coexist. `all` runs Norminette as well.

### Useful options

| Option | Description |
|---|---|
| `--only STEP` | Select `norm`, `mandatory`, `bonus`, `both`, or `all` |
| `--runs N` | Number of random performance runs per size (default: `20`) |
| `--verbose`, `-v` | Print every individual PASS/FAIL test |
| `--full` | Also test all 720 permutations of six numbers |
| `--no-norm` | Skip Norminette when using `--only all` |
| `--no-mem` | Skip Valgrind / `leaks` checks |
| `--keep-logs` | Keep the temporary test logs |
| `--no-manual` | Skip the manual defense checklist |
| `--help`, `-h` | Display the script usage summary |

Examples:

```bash
# Run mandatory tests with detailed output
./tester_detailed_full.sh --only mandatory --verbose

# Run bonus tests and keep logs
./tester_detailed_full.sh --only bonus --keep-logs

# Run both parts with 50 random performance runs
./tester_detailed_full.sh --only both --runs 50

# Run all tests, skip memory checks, and keep logs
./tester_detailed_full.sh --only all --no-mem --keep-logs

# Run all tests including all 720 permutations of six values
./tester_detailed_full.sh --only all --full
```

### Test another project directory

You can pass a project directory as the final argument:

```bash
./tester_detailed_full.sh --only all --verbose /path/to/push_swap
```

The directory must contain a `Makefile`.

## Official checker comparison (optional)

If you have an official checker binary and want the script to compare its verdicts too, set `CK_OFFICIAL`:

```bash
CK_OFFICIAL=./checker_linux ./tester_detailed_full.sh --only bonus --verbose
```

You can also use an absolute path:

```bash
CK_OFFICIAL=/path/to/checker_linux ./tester_detailed_full.sh --only bonus
```

The script also looks for common local names such as `checker_linux` and `checker_Mac`.

## Understanding the output

- `[PASS]` means that an individual automated check passed (shown with `--verbose`).
- `[FAIL]` means that a check failed. Read the test name and diagnostic printed after it.
- A group summary shows how many checks passed or failed in that group.
- `warnings` are not necessarily failures. For example, a symbol reported by `nm` needs to be checked against your project's allowed functions and subject.
- The final summary returns exit status `1` if automated tests failed, and `0` if they all passed.

When a test fails, rerun the same stage with `--verbose --keep-logs`:

```bash
./tester_detailed_full.sh --only mandatory --verbose --keep-logs
```

The script prints the temporary log directory. It also stores replay commands in `fails.txt` when applicable. Keep the logs before the script exits if you need to inspect them.
