#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:
from argparse import (ArgumentParser, RawTextHelpFormatter)
import numpy as np
import nibabel as nib

def get_parser():

    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description='add TR to 4D image '
                    )
    parser.add_argument(
        '-i', '--img', action='store', required=True,
        help='[required]'
             '\nPath to the 4D timeseries .')
    parser.add_argument(
        '-o', '--out', action='store', required=True,
        help='[required]'
             '\nOutput path.')
    parser.add_argument(
        '-t', '--trep', action='store', required=True,
        help='[required]'
             '\nTemporal mask indicating whether each volume is seen or '
             '\nunseen. For instance, 1 could indicate that a volume '
             '\nshould be retained, while 0 would indicate that the '
             '\nvolume should be censored.')

    return parser


opts            =   get_parser().parse_args()

t_rep=np.asarray(opts.trep, dtype='float64')

# Get zooms to ensure correct TR
img             =   nib.load(opts.img)
header = img.header.copy()
zooms = np.array(header.get_zooms())
zomms=list(zooms)
zooms[-1] = float(opts.trep)
header.set_zooms(tuple(zooms))

img_data=img.get_fdata()
img1      =   nib.Nifti1Image(dataobj=img_data,affine=img.affine,header=header)
nib.save(img1, opts.out)
