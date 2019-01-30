import os
from argparse import ArgumentParser
from argparse import RawTextHelpFormatter


def get_parser():
    """Defines the command line interface of the wrapper"""
    parser = ArgumentParser(
        description='xcpEngine: the extensible connectome pipeline',
        formatter_class=RawTextHelpFormatter,
        prog="xcpEngine",
        add_help=False
    )

    # Standard xcpEngine arguments
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
    optional_group.add_argument(
        "--help",
        action="store_true"
    )

    return parser
