# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:

""" surface preprocessing """

from argparse import (ArgumentParser, RawTextHelpFormatter)

import numpy as np
import sys 
from surfacefilter import surface_filt_reg

def get_parser():
    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description=' write the report for xcpEngine ')
    parser.add_argument(
        '-p', '--prefix', action='store', required=True,
        help='prefix id')
    parser.add_argument(
        '-o', '--out', action='store', required=True,
        help='outdir')
    parser.add_argument(
        '-f', '--fd', action='store', required=True,
        help='framewise displacement')
    parser.add_argument(
        '-d', '--dvars', action='store', required=True,
        help='dvars')
    parser.add_argument(
        '-t', '--tr', action='store', required=True,
        help='repetition time')
    parser.add_argument(
        '-c', '--confound', action='store', required=True,
        help='confound matrix')
    parser.add_argument(
        '-y', '--fo', action='store', required=False,default=2,
        help='temporal filter order')
    parser.add_argument(
        '-g', '--cg', action='store', required=True,
        help='cifti or gifti file')
    parser.add_argument(
        '-r', '--ord', action='store', required=True,
        help='order of processing, DMT-TMP-REG')
    parser.add_argument(
         '-l', '--lowpass', action='store', required=True,
        help=' low pass frequency')
    parser.add_argument(
         '-s', '--highpass', action='store', required=True,
        help=' high pass frequency')

    return parser

    # get file order 
opts = get_parser().parse_args()
outdir = opts.out
prefix = opts.prefix
tr = np.float(opts.tr)
filter_order = opts.fo
fd = np.loadtxt(opts.fd)
dvars = np.loadtxt(opts.dvars)
confound = np.loadtxt(opts.confound)
cg_file = opts.cg
lowpass=opts.lowpass
highpass=opts.highpass

    # get the processing steps
process_order = opts.ord.split('-')

    # get the file type
if cg_file.endswith('.dtseries.nii'):
     outfilename = outdir +'/'+ prefix +'_residualized.dtseries.nii'
     pre_svg = outdir +'/'+ prefix +'_prestats_dtseries.svg'
     post_svg = outdir +'/'+ prefix +'_residualized_dtseries.svg'
elif cg_file.endswith('L_bold.func.gii'):
     outfilename = outdir +'/'+ prefix +'_residualized_hemi-L_bold.func.gii'
     pre_svg = outdir +'/'+ prefix +'_prestats_hemi-L_bold.func.svg'
     post_svg = outdir +'/'+ prefix +'_residualized_hemi-L_bold.func.svg'
elif cg_file.endswith('R_bold.func.gii'):
     outfilename = outdir +'/'+ prefix +'_residualized_hemi-R_bold.func.gii'
     pre_svg = outdir +'/'+ prefix +'_prestats_hemi-R_bold.func.svg'
     post_svg = outdir +'/'+ prefix +'_residualized_hemi-R_bold.func.svg'
else:
    sys.exit("unknown file") 
        
    # do the processing 
surface_filt_reg(datafile=cg_file,confound=confound.T,lowpass=lowpass,highpass=highpass, 
                       outfilename=outfilename,pre_svg=pre_svg,post_svg=post_svg,process_order = process_order,
                     fd=fd,dvars=dvars,tr=tr,filter_order=filter_order)
    # processing steps 
