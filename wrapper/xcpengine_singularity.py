#!/usr/bin/env python
"""
The xcpEngine on Docker wrapper


This is a lightweight Python wrapper to run xcpEngine.
Docker must be installed and running. This can be checked
running ::

  docker info

Please report any feedback to our GitHub repository
(https://github.com/pennbbl/xcpengine) and do not
forget to credit all the authors of software that xcpEngine
uses.
"""
import sys
import os
import re
import subprocess
from warnings import warn
from .options import get_parser

__version__ = 'latest'
__packagename__ = 'xcpengine-docker'
__author__ = ''
__copyright__ = 'Copyright 2019, '
__credits__ = []
__license__ = '3-clause BSD'
__maintainer__ = ''
__email__ = ''
__url__ = 'https://github.com/pennbbl/xcpEngine'
__bugreports__ = 'https://github.com/pennbbl/xcpEngine/issues'

__description__ = """xcpEngine is a tool for denoising fMRI data and calulating
functional connectivity after preprocessing with FMRIPREP."""
__longdesc__ = """\
This package is a basic wrapper for xcpEngine that generates the appropriate
Docker commands, providing an intuitive interface to running xcpEngine
workflow in a Docker environment."""

DOWNLOAD_URL = (
    'https://pypi.python.org/packages/source/{name[0]}/{name}/{name}-{ver}.tar.gz'.format(
        name=__packagename__, ver=__version__))

CLASSIFIERS = [
    'Development Status :: 3 - Alpha',
    'Intended Audience :: Science/Research',
    'License :: OSI Approved :: BSD License',
    'Programming Language :: Python :: 3.6',
]


MISSING = """
Image '{}' is missing
Would you like to download? [Y/n] """
PKG_PATH = '/usr/local/miniconda/lib/python3.6/site-packages'

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


def check_docker():
    """Verify that docker is installed and the user has permission to
    run docker images.

    Returns
    -------
    -1  Docker can't be found
     0  Docker found, but user can't connect to daemon
     1  Test run OK
     """
    try:
        ret = subprocess.run(['docker', 'version'], stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
    except OSError as e:
        from errno import ENOENT
        if e.errno == ENOENT:
            return -1
        raise e
    if ret.stderr.startswith(b"Cannot connect to the Docker daemon."):
        return 0
    return 1


def check_image(image):
    """Check whether image is present on local system"""
    ret = subprocess.run(['docker', 'images', '-q', image],
                         stdout=subprocess.PIPE)
    return bool(ret.stdout)


def check_memory(image):
    """Check total memory from within a docker container"""
    ret = subprocess.run(['docker', 'run', '--rm', '--entrypoint=free',
                          image, '-m'],
                         stdout=subprocess.PIPE)
    if ret.returncode:
        return -1

    mem = [line.decode().split()[1]
           for line in ret.stdout.splitlines()
           if line.startswith(b'Mem:')][0]
    return int(mem)


def get_wrapper_parser():
    """Defines the command line interface of the wrapper"""
    import argparse
    parser = get_parser()

    # Allow alternative images (semi-developer)
    parser.add_argument('-i', '--image', metavar='IMG', type=str,
                        default='pennbbl/xcpEngine:{}'.format(__version__),
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
    g_dev.add_argument('-e', '--env', action='append', nargs=2, metavar=('ENV_VAR', 'value'),
                       help='Set custom environment variable within container')
    g_dev.add_argument('-u', '--user', action='store',
                       help='Run container as a given user/uid')

    return parser


def main():
    """Entry point"""

    parser = get_wrapper_parser()
    print(sys.argv)
    # Capture additional arguments to pass inside container
    opts = parser.parse_args()

    # Stop if no docker / docker fails to run
    check = check_docker()
    if check < 1:
        if opts.version:
            print('xcpEngine wrapper {!s}'.format(__version__))
        if opts.help:
            parser.print_help()
        if check == -1:
            print("xcpEngine: Could not find docker command... Is it installed?")
        else:
            print("xcpEngine: Make sure you have permission to run 'docker'")
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
        print('Downloading. This may take a while...')

    # Warn on low memory allocation
    mem_total = check_memory(opts.image)
    if mem_total == -1:
        print('Could not detect memory capacity of Docker container.\n'
              'Do you have permission to run docker?')
        return 1
    if not (opts.help or opts.version) and mem_total < 8000:
        print('Warning: <8GB of RAM is available within your Docker '
              'environment.\nSome parts of xcpEngine may fail to complete.')
        try:
            resp = input('Continue anyway? [y/N]')
        except KeyboardInterrupt:
            print()
            return 1
        if resp not in ('y', 'Y', ''):
            return 0

    command = ['docker', 'run', '--rm', '-it']

    # Patch working repositories into installed package directories
    if opts.patch_xcpEngine is not None:
        command.extend(['-v',
                        '{}:/xcpEngine:ro'.format(opts.patch_xcpEngine) ])

    if opts.env:
        for envvar in opts.env:
            command.extend(['-e', '%s=%s' % tuple(envvar)])

    if opts.user:
        command.extend(['-u', opts.user])

    main_args = []
    design_file = opts.d
    if design_file:
        if not design_file.startswith("/xcpEngine"):
            command.extend(['-v', ':'.join((design_file, '/design/design.dsn', 'ro'))])
            main_args.extend(['-d', '/design/design.dsn'])
        else:
            main_args += ['-d', design_file]

    cohort_file = opts.c
    if cohort_file:
        command.extend(['-v', ':'.join((cohort_file, '/cohort/cohort.csv', 'ro'))])
        main_args.extend(['-c', '/cohort/cohort.csv'])

    output_dir = opts.o
    if output_dir:
        command.extend(['-v', ':'.join((output_dir, '/xcpOutput'))])
        main_args.extend(['-o', '/xcpOutput'])

    # only allow serial:
    main_args += ['-m', 's']

    relative_dir = opts.r
    if relative_dir:
        command.extend(['-v', ':'.join((relative_dir, '/relative'))])
        main_args.extend(['-r', 'relative'])

    work_dir = opts.i
    if work_dir:
        command.extend(['-v', ':'.join((work_dir, '/scratch'))])
        unknown_args.extend(['-i', '/scratch'])

    if opts.shell:
        command.append('--entrypoint=bash')

    command.append(opts.image)

    # Override help and version to describe underlying program
    # Respects '-i' flag, so will retrieve information from any image
    if opts.help:
        command.append('-h')
        targethelp = subprocess.check_output(command).decode()
        print(merge_help(parser.format_help(), targethelp))
        return 0

    if not opts.shell:
        command.extend(main_args)

    print("RUNNING: " + ' '.join(command))
    ret = subprocess.run(command)
    if ret.returncode:
        print("xcpEngine: Please report errors to {}".format(__bugreports__))
    return ret.returncode


if __name__ == '__main__':
    sys.exit(main())
