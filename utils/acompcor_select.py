#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:

import json
import pandas as pd 
from argparse import (ArgumentParser, RawTextHelpFormatter)


def get_parser():

    parser = ArgumentParser(
        formatter_class=RawTextHelpFormatter,
        description='acompcor selection')
    parser.add_argument(
        '-c', '--confmat', action='store', required=True,
        help='[required]'
             '\n confmat.')
    parser.add_argument(
        '-j', '--confjson', action='store', required=True,
        help='[required]'
             '\n conjson.')
    parser.add_argument(
        '-o', '--outfile', action='store', required=False,
        help='output directory')
    return parser

opts            =   get_parser().parse_args()

   
with open(opts.confjson) as f:
    data = json.load(f)

WM=[]
CSF=[]
for key, value in data.items():
    if 'a_comp_cor' in key:
        if value['Mask']=='WM' and value['Retained']==True:
            WM.append([key,value['VarianceExplained']])
        if value['Mask']=='CSF' and value['Retained']==True:
            CSF.append([key,value['VarianceExplained']])

CSFlist=[CSF[0][0],CSF[1][0],CSF[2][0],CSF[3][0],CSF[4][0]]
WMlist=[WM[0][0],WM[1][0],WM[2][0],WM[3][0],WM[4][0]] 

data2=pd.read_csv(opts.confmat,sep='\t')
combinelist=CSFlist+WMlist
acompcor=data2[combinelist]
acompcor.to_csv(opts.outfile,index=False,sep=' ',header=False)

    

    

    