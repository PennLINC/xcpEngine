#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:

from argparse import (ArgumentParser, RawTextHelpFormatter)
from nilearn.image import (threshold_img, load_img)
from nilearn.plotting import (plot_epi,plot_matrix,plot_stat_map)
from niworkflows.viz.utils import *
from niworkflows.viz.plots import *
import json
import nibabel as nib
import matplotlib.pyplot as plt
import pandas as pd

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
        '-m', '--modules', action='store', required=True,
        help='list of modules run')
    parser.add_argument(
        '-t', '--template', action='store', required=True,
        help='template')
    
    return parser
opts            =   get_parser().parse_args()
outdir=opts.out
prefix=opts.prefix
pipeline=opts.modules
template=opts.template

##  read the csv file
#required QC to be  read out 
modules=pd.read_csv(pipeline)
def ulify(elements):
    string = "<ul>\n"
    for s in elements:
        string += "<li>" + str(s) + "</li>\n"
    string += "</ul>"
    return string

modulelist=ulify(modules)

modulewant=['coreg','prestats','struc','norm','qcfc','jlf','fcon','alff','reho','cbf','basil','score','scrub']
modules1=[]
for j in modulewant:
     if j in modules:
          modules1.append(j)

qcfile=outdir+'/'+prefix+'_quality.csv'
qc=pd.read_csv(qcfile)
removec=qc.columns[ qc.columns.str.startswith('id')]
qc=qc.drop(removec,axis='columns')

qc_required=['regCoverage','regCrossCorr','regDice','regJaccard','coregCrossCorr','coregJaccard','coregDice','coregCoverage',
        'relMeanRMSMotion','relMaxRMSMotion','nNuisanceParameters','nVolCensored','normDice','normCoverage','normJaccard','normCrossCorr',
        'negativeVoxels']
df = pd.DataFrame(qc,columns=qc_required).dropna(axis='columns')



html_table = qc.to_html(index=False)
html_report='<html> <head> <h1> xcpEngine report </h1>  </head> <body> <h2> Modules: ' + modulelist + '</h2> <h2> QC </h2> ' + html_table + '' 

#modules=modules.drop(['qcanat'],axis=1)
for i in modules1:
    if i == 'struc':
        extrabrain=outdir+'/struc/'+prefix+'_ExtractedBrain0N4.nii.gz'
        seg=[outdir+'/struc/'+prefix+'_BrainSegmentationPosteriors001.nii.gz',
             outdir+'/struc/'+prefix+'_BrainSegmentationPosteriors002.nii.gz',
             outdir+'/struc/'+prefix+'_BrainSegmentationPosteriors003.nii.gz',
             outdir+'/struc/'+prefix+'_BrainSegmentationPosteriors004.nii.gz',
             outdir+'/struc/'+prefix+'_BrainSegmentationPosteriors005.nii.gz',
             outdir+'/struc/'+prefix+'_BrainSegmentationPosteriors006.nii.gz']
        fig=plot_segs(image_nii=extrabrain,seg_niis=seg,out_file='report.svg',masked=False,bbox_nii=extrabrain)
        compose_view(bg_svgs=fig,fg_svgs=None,ref=0,out_file=outdir+'/figures/'+prefix+'_struct_report.svg')
        segplot='figures/'+prefix+'_struct_report.svg'
        moving=load_img(outdir+'/struc/'+prefix+'_BrainNormalizedToTemplate.nii.gz')
        mask=threshold_img(moving,1e-3)
        cuts=cuts_from_bbox(mask_nii=mask,cuts=7)
        f1=plot_registration(moving,'fixed-image',cuts=cuts,label='Extracted Brain')
        f2=plot_registration(load_img(template),'moving-image',cuts=cuts,label='Template')
        compose_view(f1,f2,out_file=outdir+'/figures/'+prefix+'_registration.svg')
        structreg='figures/'+prefix+'_registration.svg'
        html_report=html_report + '<h1> struc module </h1> <h3> Brain segmentation </h3>  <p>Extracted brain with segmented tissues (contours).</p>  <img src="'+ segplot + '" alt="Segmentation" width="2000"height="800"> \
        <h3> Registration </h3> <p>T1w registered to the  template .</p>  <object type="image/svg+xml" data="'+ structreg + '" alt="Segmentation" width="2000"height="800"></object>'
    elif i == 'jlf':
         jlf_label=load_img(outdir+'/jlf/'+prefix+'_Labels.nii.gz')
         plot_epi(epi_img=jlf_label,output_file=outdir+'/figures/'+prefix+'_label.svg',display_mode='z',cut_coords=7,draw_cross=False,title='Jlf atlas')
         jflplot='figures/'+prefix+'_label.svg'
         html_report=html_report + '<h1> jlf module </h1> <h3> JLF attlas  </h3> <object type="image/svg+xml" data="'+ jflplot + '" alt="Segmentation" width="2000"height="800"></object>'
    elif i == 'prestats':
         checkfile = os.path.isfile(outdir+'/prestats/'+prefix+'_segmentation.nii.gz')
         if checkfile:
            moving=load_img(outdir+'/prestats/'+prefix+'_referenceVolumeBrain.nii.gz')
            fixedim=load_img(outdir+'/prestats/'+prefix+'_structbrain.nii.gz')
            mask=threshold_img(moving,1e-3)
            cuts=cuts_from_bbox(mask_nii=mask,cuts=7)
            f1=plot_registration(moving,'fixed-image',cuts=cuts,label='functional')
            f2=plot_registration(fixedim,'moving-image',cuts=cuts,label='structural')
            compose_view(f1,f2,out_file=outdir+'/figures/'+prefix+'_registration.svg')
            fmreg='figures/'+prefix+'_registration.svg'
            html_report=html_report + '<h1> prestats module </h1> <h3> Registration </h3> <p> Functional registration to Structural .</p> <object type="image/svg+xml" data="'+ fmreg+ '" alt="Segmentation" width="2000"height="800"></object>'
    elif i == 'regress':
         segm=outdir+'/prestats/'+prefix+'_segmentation.nii.gz'
         seg_data=load_img(segm).get_data()
         resid=outdir+'regress/'+prefix+'_residualised.nii.gz'
         tr=nib.load(resid).header['pixdim'][4]
         plot_carpet(img=resid,atlaslabels=seg_data,tr=tr,output_file=outdir+'/regress/'+prefix+'_residualized.svg')
         residplot='regress/'+prefix+'_residualized.svg'
         html_report=html_report + '<h1> regress module </h1> <h3> Residualized BOLD data </h3> <object type="image/svg+xml" data="'+ residplot +'" alt="Segmentation" width="1000"height="800"></object>'
    elif i == 'fcon' :
         filejson=outdir+'/'+prefix+'_atlas/'+prefix+'_atlas.json'
         with open(filejson, 'r') as atlasfile:
              data_atlas=atlasfile.read()

         objatlas = json.loads(data_atlas)
         atlaslist=[]
         for k in objatlas .keys():
             atlaslist.append(k)
         atlaslist.remove('global')
         atlaslist.remove('segmentation')

         ng=0         
         np1=len(atlaslist)
         plt.clf()#ii=atlaslist[0]
         plt.cla()
         fig = plt.figure()
         fig,ax1 = plt.subplots(1,np1)
         fig.set_size_inches(500,500)
         font = {
        'weight': 'normal',
        'size': 200}

         for ii in atlaslist:
             tms=np.loadtxt(outdir+'/fcon/'+ii+'/'+prefix+'_'+ii+'_ts.1D')
             cormatrix=np.nan_to_num(np.corrcoef(tms.T))
             axs=ax1[ng]
             axs.set_title(ii,fontdict=font)
             plot_matrix(mat=cormatrix,colorbar=False,vmax=1,vmin=-1,axes=axs)
             ng +=1
         fig.savefig(outdir+'/figures/'+prefix+'_corrplot.svg',bbox_inches="tight",pad_inches=None)
         corrplot='figures/'+prefix+'_corrplot.svg'
         html_report=html_report + '<h1> fcon module </h1> <h3> Functional connectivity matrices  </h3> <object type="image/svg+xml" data="'+ corrplot +'" alt="Segmentation" width="4000"height="500"></object>'
    elif i == 'alff' :
         statmapalff=load_img(outdir+'/alff/'+prefix+'_alffZ.nii.gz')
         bgimg=load_img(outdir+'/alff/'+prefix+'_referenceVolume.nii.gz')
         plot_stat_map(stat_map_img=statmapalff,bg_img=bgimg,display_mode='z',cut_coords=7,draw_cross=False,cmap='jet',
                           symmetric_cbar=True,vmax=2,output_file=outdir+'/figures/'+prefix+'_alff.svg',colorbar=True,title='alffZ')
         alffplot='figures/'+prefix+'_alff.svg'
         html_report=html_report + '<h1> alff module </h1> <object type="image/svg+xml" data="'+ alffplot +'" alt="Segmentation" width="2000"height="400"></object>'
    elif i == 'reho' :
         statmapreho=load_img(outdir+'/reho/'+prefix+'_rehoZ.nii.gz')
         bgimg=load_img(outdir+'/reho/'+prefix+'_referenceVolume.nii.gz')
         plot_stat_map(stat_map_img=statmapreho,bg_img=bgimg,display_mode='z',cut_coords=7,draw_cross=False,cmap='jet',
                           symmetric_cbar=True,vmax=2,output_file=outdir+'/figures/'+prefix+'_reho.svg',colorbar=True,title='rehoZ')
         rehoplot='figures/'+prefix+'_reho.svg'
         html_report=html_report + '<h1> reho module </h1> <object type="image/svg+xml" data="'+ rehoplot +'" alt="Segmentation" width="2000"height="400"></object>'
    elif i == 'norm' :
           moving=load_img(outdir+'/norm/'+prefix+'_referenceVolumeBrainStd.nii.gz')
           mask=threshold_img(moving,1e-3)
           cuts=cuts_from_bbox(mask_nii=mask,cuts=7)
           f1=plot_registration(moving,'fixed-image',cuts=cuts,label='Functional')
           f2=plot_registration(load_img(template),'moving-image',cuts=cuts,label='Template')
           compose_view(f1,f2,out_file=outdir+'/figures/'+prefix+'_normalization.svg')
           normreg='figures/'+prefix+'_normalization.svg'
           html_report=html_report + '<h1> norm module </h1>  <p> Functional normalization to the Template <p> <object type="image/svg+xml" data="'+ normreg + '" alt="Segmentation" width="2000"height="800"></object>'
    elif i == 'coreg':
           moving=load_img(outdir+'/coreg/'+prefix+'_seq2struct.nii.gz')
           fixedim=load_img(outdir+'/coreg/'+prefix+'_target.nii.gz')
           mask=threshold_img(moving,1e-3)
           cuts=cuts_from_bbox(mask_nii=mask,cuts=7)
           f1=plot_registration(moving,'fixed-image',cuts=cuts,label='seq2struct')
           f2=plot_registration(fixedim,'moving-image',cuts=cuts,label='struct')
           compose_view(f1,f2,out_file=outdir+'/figures/'+prefix+'_registration.svg')
           natreg='figures/'+prefix+'_registration.svg'
           html_report=html_report + '<h1> coreg module </h1>  <p> Coregistration of T1w and Fucntional image <p> <object type="image/svg+xml" data="'+ natreg + '" alt="Segmentation" width="2000"height="800"></object>'
    elif i == 'cbf' :
         statmapcbf=load_img(outdir+'/cbf/'+prefix+'_meanPerfusion.nii.gz')
         bgimg=load_img(outdir+'/prestats/'+prefix+'_referenceVolume.nii.gz')
         plot_stat_map(stat_map_img=statmapcbf,bg_img=bgimg,display_mode='z',cut_coords=7,draw_cross=False,vmax=120,
                           symmetric_cbar=True,output_file=outdir+'/figures/'+prefix+'_cbf.svg',colorbar=True,title='mean CBF')
         cbfplot='figures/'+prefix+'_cbf.svg'
         html_report=html_report + '<h1> cbf module <h1> <object type="image/svg+xml" data="'+ cbfplot + '" alt="Segmentation" width="2000"height="400"></object>'
    elif i == 'basil' :
         statmapbasil=load_img(outdir+'/basil/'+prefix+'_cbf_basil.nii.gz')
         bgimg=load_img(outdir+'/prestats/'+prefix+'_referenceVolume.nii.gz')
         plot_stat_map(stat_map_img=statmapbasil,bg_img=bgimg,display_mode='z',cut_coords=7,draw_cross=False,vmax=120,
                           symmetric_cbar=True,output_file=outdir+'/figures/'+prefix+'_basil.svg',colorbar=True,title='basil CBF')
         basilplot='figures/'+prefix+'_basil.svg'
         html_report=html_report + '<h1> basil module </h1>  <object type="image/svg+xml" data="'+ basilplot + '" alt="Segmentation" width="2000"height="400"></object>'
    elif i == 'score' :
         statmapscore=load_img(outdir+'/score/'+prefix+'_cbfscore.nii.gz')
         bgimg=load_img(outdir+'/prestats/'+prefix+'_referenceVolume.nii.gz')
         plot_stat_map(stat_map_img=statmapscore,bg_img=bgimg,display_mode='z',cut_coords=7,draw_cross=False,vmax=120,
                           symmetric_cbar=True,output_file=outdir+'/figures/'+prefix+'_score.svg',colorbar=True,title='score CBF')
         scoreplot='figures/'+prefix+'_score.svg'
         html_report=html_report + '<h1> score module <h1> <object type="image/svg+xml" data="'+ scoreplot + '" alt="Segmentation" width="2000"height="400"></object>'
    elif i == 'scrub' :
         statmapscrub=load_img(outdir+'/scrub/'+prefix+'_cbfscrub.nii.gz')
         bgimg=load_img(outdir+'/prestats/'+prefix+'_referenceVolume.nii.gz')
         plot_stat_map(stat_map_img=statmapscrub,bg_img=bgimg,display_mode='z',cut_coords=7,draw_cross=False,vmax=120,
                           symmetric_cbar=True,output_file=outdir+'/figures/'+prefix+'_scrub.svg',colorbar=True,title='scrub CBF')
         scrubplot='figures/'+prefix+'_scrub.svg'
         html_report=html_report + '<h1> scrub module </h1> <object type="image/svg+xml" data="'+ scrubplot + '" alt="Segmentation" width="2000"height="400"></object>'
    elif i == 'roiquant' :
         filejson=outdir+'/'+prefix+'_atlas/'+prefix+'_atlas.json'
         with open(filejson, 'r') as atlasfile:
              data_atlas=atlasfile.read()

         objatlas = json.loads(data_atlas)
         atlaslist=[]
         for k in objatlas .keys():
             atlaslist.append(k)
         atlasused=ulify(atlaslist)
         html_report=html_report + '<h1> roiquant module </h1> <h3> The atlas used: ' + atlasused +' </h3> ' 
    elif i == 'qcfc' :
         os.system('cp '+ outdir+'/qcfc/'+prefix+'_voxts.png ' +outdir+'/figures/'+prefix+'_voxts.png')
         qcplot='figures/'+prefix+'_voxts.png'
         html_report=html_report + '<h1> qcfc module </h1>  <h3> <p>  The spike plot consists of dvars (DV), relative motion (RMS) and framewise displacement (FD),  \
         The middle carpet plot is the raw BOLD data and bottom carpet plot is residualized BOLD data </p>  <p> Check motionDVCorrInit (correlation of DV and RMS before regression) and motionDVCorrFinal \
         (correlation of DV and RMS after regression) in the QC table above  </p> </h3>  <object type="image/svg+xml" data="'+ qcplot + '" alt="Segmentation" width="2000"height="1500"></object>'
    else :
        html_report=html_report + '</body>  </html>'

filereport= open(outdir+'/'+prefix+'_report.html','w')
filereport.write(html_report)
filereport.close()
