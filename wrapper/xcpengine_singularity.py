#!/usr/bin/env python
"""
The xcpEngine Singularity wrapper


This is a lightweight Python wrapper to run xcpEngine.
Singularity must be installed. This can be checked
running ::

  singularity selftest

Please report any feedback to our GitHub repository
(https://github.com/pennbbl/xcpengine) and do not
forget to credit all the authors of software that xcpEngine
uses.
"""
import sys
import stat
import os
import os.path as op
import re
import subprocess
from warnings import warn
from options import get_parser
home = os.path.expanduser("~")
__version__="latest"


MISSING = """
Image '{}' is missing
Would you like to download? [Y/n] """

# Monkey-patch Py2 subprocess
if not hasattr(subprocess, 'DEVNULL'):
    subprocess.DEVNULL = -3

if not hasattr(subprocess, 'run'):
    # Reimplement minimal functionality for usage in this file
    def _run(args, stdout=None, stderr=None):
        from collections import namedtuple
        result = namedtuple('CompletedProcess', 'stdout stderr returncode')

        devnull = None
        if subprocess.DEVNULL in (stdout, stderr):
            devnull = open(os.devnull, 'r+')
            if stdout == subprocess.DEVNULL:
                stdout = devnull
            if stderr == subprocess.DEVNULL:
                stderr = devnull

        proc = subprocess.Popen(args, stdout=stdout, stderr=stderr)
        stdout, stderr = proc.communicate()
        res = result(stdout, stderr, proc.returncode)

        if devnull is not None:
            devnull.close()

        return res
    subprocess.run = _run


# De-fang Python 2's input - we don't eval user input
try:
    input = raw_input
except NameError:
    pass


def check_singularity():
    """Verify that singularity is installed and the user has permission to
    run singularity images.

    Returns
    -------
    -1  singularity can't be found
     1  Test run OK
     """
    try:
        ret = subprocess.run(['singularity', '--version'],
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
    except OSError as e:
        from errno import ENOENT
        if e.errno == ENOENT:
            return -1
        raise e
    return 1


def check_image(image):
    """Check whether image is present and you can read it"""
    return os.path.exists(image) and os.access(image, os.R_OK)


def get_wrapper_parser():
    """Defines the command line interface of the wrapper"""
    import argparse
    parser = get_parser()

    # Allow alternative images (semi-developer)
    parser.add_argument('--image', metavar='IMG', type=str,
                        default=os.path.join(home,"xcpEngine.simg"),
                        help='image name')

    # Options for mapping files and directories into container
    # Update `expected_overlap` variable in merge_help() when adding to this
    g_wrap = parser.add_argument_group(
        'Wrapper options',
        'Standard options that require mapping files into the container')

    # Developer patch/shell options
    g_dev = parser.add_argument_group(
        'Developer options',
        'Tools for testing and debugging xcpEngine')
    g_dev.add_argument('-f', '--patch-xcpEngine', metavar='PATH',
                       type=os.path.abspath,
                       help='working xcpEngine repository')
    g_dev.add_argument('--shell', action='store_true',
                       help='open shell in image instead of running xcpEngine')

    return parser

def mkdir(dirpath):
    if op.exists(dirpath):
        return 1
    try:
        os.makedirs(dirpath)
    except Exception:
        print("Unable to create {}. Exiting.".format(dirpath))
        sys.exit(1)


def main():
    """Entry point"""

    parser = get_wrapper_parser()
    print(sys.argv)
    # Capture additional arguments to pass inside container
    opts = parser.parse_args()

    # Stop if no docker / docker fails to run
    check = check_singularity()
    if check < 1:
        if opts.version:
            print('xcpEngine wrapper {!s}'.format(__version__))
        if opts.help:
            parser.print_help()
        else:
            print("xcpEngine: Could not singularity command... Is it installed?")
        return 1

    # For --help or --version, ask before downloading an image
    if not check_image(opts.image):
        resp = 'Y'
        if opts.version:
            print('xcpEngine wrapper {!s}'.format(__version__))
        if opts.help:
            parser.print_help()
        if opts.version or opts.help:
            try:
                resp = input(MISSING.format(opts.image))
            except KeyboardInterrupt:
                print()
                return 1
        if resp not in ('y', 'Y', ''):
            return 0
        print('Downloading and building image. This may take a while...')
        ret = subprocess.run(
            "singularity build {} docker://pennbbl/xcpengine:latest".format(opts.image))
        if ret > 0:
            print("Critical Error: Unable to create singularity image {}".format(opts.image))
            sys.exit(1)

    # Warn on low memory allocation
    mem_bytes = os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES')
    mem_gib = mem_bytes/(1024.**3)
    if mem_gib < 10:
        print('Warning: <10GB of RAM is available on your system.\n'
              'Some parts of xcpEngine may fail to complete.')

    command = ['singularity', 'run']

    # Patch working repositories into installed package directories
    if opts.patch_xcpEngine is not None:
        if not os.path.exists(opts.patch_xcpEngine):
            print("WARNING: unable to patch xcpEngine. {} does not "
                  "exist".format(opts.patch_xcpEngine))
        else:
            command.extend(['-B',
                            '{}:/xcpEngine'.format(opts.patch_xcpEngine) ])

    main_args = []
    design_file = opts.d
    if design_file:
        if not design_file.startswith("/xcpEngine"):
            design_dir, design_fname = op.split(design_file)
            mounted_name = "/design/" + design_fname
            command.extend(['-B', design_dir + ':/design'])
            main_args.extend(['-d', mounted_name])
        else:
            main_args += ['-d', design_file]

    cohort_file = opts.c
    if cohort_file:
        cohort_dir, cohort_fname = op.split(cohort_file)
        mounted_cohort = "/cohort/" + cohort_fname
        command.extend(['-B', cohort_dir + ':/cohort'])
        main_args.extend(['-c', mounted_cohort])

    output_dir = opts.o
    if output_dir:
        mkdir(output_dir)
        command.extend(['-B', ':'.join((output_dir, '/out'))])
        main_args.extend(['-o', '/out'])

    # only allow serial:
    main_args += ['-m', 's']

    relative_dir = opts.r
    if relative_dir:
        command.extend(['-B', ':'.join((relative_dir, '/data'))])
        main_args.extend(['-r', '/data'])

    work_dir = opts.i
    if work_dir:
        mkdir(work_dir)
        command.extend(['-B', ':'.join((work_dir, '/work'))])
        main_args.extend(['-i', '/work'])

    if opts.shell:
        command[1] = "shell"

    command.append(opts.image)

    if not opts.shell:
        command.extend(main_args)

    print("RUNNING: " + ' '.join(command))
    ret = subprocess.run(command)
    if ret.returncode:
        print("xcpEngine: Please report errors to {github.com/pennbbl/xcpEngine/issues}")
    return ret.returncode


if __name__ == '__main__':
    sys.exit(main())
