
import sys
import os
import stat
import os.path as op
import re
import subprocess
from warnings import warn
from argparse import ArgumentParser
from argparse import RawTextHelpFormatter
import pandas as pd


def get_parser():
    """Defines the command line interface of the wrapper"""
    parser = ArgumentParser(
        description='xcpEngine: the extensible connectome pipeline',
        formatter_class=RawTextHelpFormatter,
        prog="xcpEngine"
    )

    # Standard qsiprep arguments
    mandatory_group = parser.add_argument_group('Mandatory options')
    mandatory_group.add_argument(
        '-d',
        type=os.path.abspath,
        required=True,
        action='store',
        help="Primary design file for pipeline: "
        "The design file specifies the pipeline modules to "
        "be included in the current analysis and configures "
        "any parameters necessary to run the modules.")
    mandatory_group.add_argument(
        '-c',
        required=True,
        action='store',
        help="Cohort file for pipeline input: "
        "A comma-separated catalogue of the analytic sample. "
        "Each row corresponds to a subject, and each column "
        "corresponds either to an identifier or to an input.")
    mandatory_group.add_argument(
        '-o',
        required=True,
        action='store',
        help="Parent directory for pipeline output: "
        "A valid path on the current filesystem specifying "
        "the directory wherein all output from the current "
        "analysis will be written.")

    optional_group = parser.add_argument_group('Optional Arguments')
    optional_group.add_argument(
        '-m',
        choices=["s", "c"],
        action='store',
        help="Execution mode: "
        "Input can either be 's' (for serial execution on a "
        "single machine)[default], 'c' (for execution on a "
        "computing cluster) or a path to a file (for execution "
        "on a computing cluster, subject to the specifications "
        "defined in the file).")
    optional_group.add_argument(
        '-i',
        action='store',
        help=": Scratch space for pipeline intermediates: "
        "Some systems operate more quickly when temporary "
        "files are written in a dedicated scratch space. This "
        "argument enables a scratch space for intermediates.")
    optional_group.add_argument(
        '-r',
        action='store',
        help="Root directory for inputs: "
        "If all paths defined in the cohort file are defined "
        "relative to a root directory, then this argument will "
        "define the root directory. Otherwise, all paths will "
        "be treated as absolute.")
    optional_group.add_argument(
        '-t',
        action='store',
        choices=["0", "1", "2", "3"],
        help="Integer value ( 0 - 3 ) that indicates the level "
        "of verbosity during module execution. Higher "
        "levels reduce readability but provide useful "
        "information for troubleshooting.")

    return parser


def main():
    """Check that the inputs are ok. If not, print a very verbose error."""
    print("""\


======================== Checking Inputs =============================


""")
    parser = get_parser()
    try:
        args = parser.parse_args()
    except Exception:
        parser.print_help()
        sys.exit(1)

    # Check that the args are all sane
    design_file = args.d
    verbose_file_check("-d", design_file, makedir=False)

    working_dir = args.i
    if working_dir is not None:
        verbose_file_check("-i", working_dir, makedir=True)

    relative_dir = args.r
    if relative_dir is not None:
        verbose_file_check("-r", relative_dir, makedir=False)

    cohort_file = args.c
    verbose_file_check("-c", cohort_file, makedir=False)
    check_cohort_file(cohort_file, relative_dir)

    return 0


def verbose_file_check(optname, filepath, makedir=False):
    file_dir, file_name = op.split(filepath)
    if not op.exists(filepath):
        if not makedir:
            message = '''\
Error: Unable to load {filepath}, which was specified for option {optname}

Check that {file_dir} exists and you have permission to read it.
If you are using Docker or Singularity, make sure that {file_dir}
is correctly mounted and you can access it from within the container.

Remember that this path does not use the ``-r`` argument, but is a full
path to the file.

If using a container, you may find the documentation helpful for
interactively checking whether a file is accessible from within a
container (https://xcpengine.readthedocs.io/containers/index.html).
'''.format(filepath=filepath, optname=optname, file_dir=file_dir)
            print(message)
            sys.exit(1)

        # The directory would be created by xcp
        else:
            try:
                os.makedirs(filepath)
            except PermissionError:
                message = '''\
Error: You don't have permission to create a directory {filepath}, which
was specified to option {optname}. This directory would normally be
created by xcpEngine, but this cannot be done in this case.

If using a container, you may find the documentation helpful for
interactively checking whether a file is accessible from within a
container (https://xcpengine.readthedocs.io/containers/index.html).
'''.format(filepath=filepath, optname=optname)
                print(message)
                sys.exit(1)

    # Check read permission
    read_access = os.access(filepath, os.R_OK)
    if not read_access:
        message = '''\
Error: You don't have permission to read {filepath}, which
was specified to option {optname}.

If you are using Docker or Singularity, make sure that {file_dir}
is correctly mounted and you can access it from within the container.

If using a container, you may find the documentation helpful for
interactively checking whether a file is accessible from within a
container (https://xcpengine.readthedocs.io/containers/index.html).
'''.format(filepath=filepath, optname=optname)
        print(message)
        sys.exit(1)


def check_cohort_file(cohort_file, relative_path):

    special_file_columns = ["confound2_custom"]
    try:
        cohort = pd.read_csv(cohort_file)
    except Exception as e:
        message = '''\
Error: unable to parse cohort file {cohort_file}
'''.format(cohort_file=cohort_file, error=e)
        print(message)
        sys.exit(1)

    # Loop over the columns and check they're ok
    columns = cohort.columns
    for column in columns:
        if column.startswith("id"):
            # Check that the rest of it is an Integer
            try:
                int(column[2:])
            except ValueError:
                print("Error: id columns must start with id and end with something "
                      "that can be converted to an integer. You specified an "
                      "illegal value '%s'" % column)
                sys.exit(1)

            # Check that The values are ok
            column_values = cohort[column]
            for rownum, value in enumerate(column_values):
                illegal_chars = re.match("([^.A-Za-z0-9_-])", value)
                if illegal_chars is not None:
                    cant_use = ''.join(illegal_chars.groups())
                    print("Error: Column {column}, Row {rownum} is {value}, which contains "
                          "special character(s) {cant_use}. Remove this character and "
                          "try again.".format(column=column, rownum=rownum, value=value,
                                              cant_use=cant_use))
                    sys.exit(1)

        elif column in ("img", "antsct", "confound2_custom"):
            for rownum, img in enumerate(cohort['img']):
                check_cohort_file_cell(rownum, column, img, relative_path, cohort_file)

        else:
            print("Error: column name {column} was found in {cohort_file}. This is not among "
                  "{'id[0-9]+', 'img', 'antsct', 'confound2_custom'}, which are the legal "
                  "column headers.")
            sys.exit(1)


def check_cohort_file_cell(rownum, column, value, rel, cohort_file):
    relative_msg = ""
    full_path=value
    if rel is not None:
        full_path = rel + value
        relative_msg = "Using relative path {rel}, the file {original_file} evaluates " \
                       "to {full_path}".format(rel=rel, original_file=value,
                                               full_path=full_path)

    if not op.exists(full_path):
        message = '''\
Error: file specified in {cohort_file} Column {column}, Row {rownum} is not readable

{relative_msg}
The file {value} cannot be read.

If using a container, you may find the documentation helpful for
interactively checking whether a file is accessible from within a
container (https://xcpengine.readthedocs.io/containers/index.html).

For an overview of cohort files and their contents see
https://xcpengine.readthedocs.io/config/index.html#cohort-file-and-reference-directory
'''.format(value=value, rownum=rownum, column=column, cohort_file=cohort_file,
           relative_msg=relative_msg)
        print(message)
        sys.exit(1)


if __name__ == '__main__':
    sys.exit(main())
