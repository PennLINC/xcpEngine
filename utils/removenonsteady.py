#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:


from argparse import (ArgumentParser, RawTextHelpFormatter)
import numpy as np
import nibabel as nib
import pandas as pd

#AZEEZ

def get_parser():

    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description='Remove non steady volumes '
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
        '-t', '--tab', action='store', required=True,
        help='[required]'
             '\n confound regressors table')
    parser.add_argument(
        '-s', '--sab', action='store', required=True,
        help='[required]'
             '\n return confound regressors table')

    return parser


opts = get_parser().parse_args()

img = nib.load(opts.img)
img_data = img.get_fdata()

tab = pd.read_csv(opts.tab, sep='\t')
tad = tab.loc[:, tab.columns.str.contains('non_steady_state')]
tads = tad.sum(axis=1, skipna=True)

dvol = tads[tads > 0]
ndvol = len(dvol)
if (ndvol >= 1):
    newtab = tab.iloc[ndvol:]
    new_image = img_data[:, :, :, (ndvol-1):-1]
    img1 = nib.Nifti1Image(
        dataobj=new_image, affine=img.affine, header=img.header)
    print("first " + str(ndvol) + " non steady state volume(s) will be deleted")
else:
    print("No non steady state volumes")
    img1 = nib.Nifti1Image(
        dataobj=img_data, affine=img.affine, header=img.header)
    newtab = tab

nib.save(img1, opts.out)
newtab.to_csv(opts.sab, encoding='utf-8', index=False, sep='\t')
