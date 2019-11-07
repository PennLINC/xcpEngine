#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:


from argparse import (ArgumentParser, RawTextHelpFormatter)
import numpy as np
import pandas as pd

#AZEEZ

def get_parser():

    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description='Remove non steady volumes '
    )
    parser.add_argument(
        '-n', '--nvd', action='store', required=True,default=0,
        help=' number of line to be deleted')
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

nvd=opts.nvd
tab = pd.read_csv(opts.tab, sep='\t')
tad = tab.loc[:, 1:nvd]
newtab.to_csv(opts.sab, encoding='utf-8', index=False, sep='\t')
