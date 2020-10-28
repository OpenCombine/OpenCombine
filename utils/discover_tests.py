"""
Parse test files and generate LinuxMain.swift.

This script uses simple regular expressions to extract test names from test files.
We don't use --enable-test-discovery because:
  * it doesn't work with Swift 5.0 that we still support
  * there are other problems with it: https://bugs.swift.org/browse/SR-10783
"""
import sys

if sys.version_info < (3, 6, 0):
    exit("This script only works with Python 3.6 and newer.")

import re
from pathlib import Path
from argparse import ArgumentParser

TEST_METHOD_PATTERN = \
    re.compile(r"func\s*(test\w+)\s*\(\s*\)\s*(?:throws\s*)?{")
TEST_DISCOVERY_CONDITION_PATTERN = \
    re.compile(r"^#if (.+)\s*\/\/\s*TEST_DISCOVERY_CONDITION\s*$", flags=re.MULTILINE)

def extract_test_names(test_file):
    contents = test_file.read_text()
    test_names = [match[1] for match in TEST_METHOD_PATTERN.finditer(contents)]
    condition = TEST_DISCOVERY_CONDITION_PATTERN.search(contents)
    return (test_names, condition[1] if condition else None)

def generate_linuxmain(workdir):
    workdir = Path(workdir)
    tests_dir = workdir / "Tests"
    test_files = (tests_dir / "OpenCombineTests").glob("*/*Tests.swift")

    with (tests_dir / "LinuxMain.swift").open(mode="w") as linuxmain:
        linuxmain.write("""\
import XCTest

@testable import OpenCombineTests

var tests = [XCTestCaseEntry]()

""")
        for test_file in test_files:
            (test_names, condition) = extract_test_names(test_file)
            if not test_names:
                continue
            if condition:
                linuxmain.write(f"#if {condition}\n")
            linuxmain.write(f"let allTests_{test_file.stem} = [\n")
            for test_name in test_names:
                linuxmain.write(f"    (\"{test_name}\", {test_file.stem}.{test_name}),\n")
            linuxmain.write("]\n")
            linuxmain.write(f"tests.append(testCase(allTests_{test_file.stem}))\n")
            if condition:
                linuxmain.write("#endif\n")
            linuxmain.write("\n")

        linuxmain.write("XCTMain(tests)")


if __name__ == "__main__":
    parser = ArgumentParser(description="Generates LinuxMain.swift for OpenCombine tests")
    parser.add_argument("workdir", type=Path, nargs="?",
                        help="The root directory of the OpenCombine Swift package")
    args = parser.parse_args()
    workdir = args.workdir or Path.cwd()
    generate_linuxmain(workdir)
