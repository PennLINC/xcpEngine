#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:

from argparse import (ArgumentParser, RawTextHelpFormatter)
import nibabel as nib
from nilearn.image import (threshold_img, load_img,math_img)
from nilearn.plotting import (plot_epi,plot_matrix,plot_stat_map)
from utils import *
from  plots import *
import json
import matplotlib.pyplot as plt
import matplotlib as mp
from matplotlib import gridspec
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
font = {
                'weight': 'normal',
               'size': 20}

mp.rc('font', **font)

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



modulewant=['coreg','prestats','task','struc','norm','qcfc','jlf','fcon','alff','reho','cbf','basil','scorescrub','regress']
modules1=[]
for j in modulewant: 
     if j in modules:
          modules1.append(j)

spacejson=outdir+'/'+prefix+'_spaces.json'
with open(spacejson, 'r') as spacefile:
     data_space=spacefile.read()
     objspace = json.loads(data_space)

spaceout=str(objspace)
findspace=spaceout.find('h5')


if 'regress' in modules1: 
    funct='BOLD'
    imagetype='Functional'
    himg=load_img(outdir+'/prestats/'+prefix+'_preprocessed.nii.gz').header
    himg=load_img(outdir+'/prestats/'+prefix+'_preprocessed.nii.gz').header
    nvols=str(himg.get_data_shape()[-1])
    Dim=str(himg.get_data_shape()[0]) +'x'+ str(himg.get_data_shape()[1])+'x'+str(himg.get_data_shape()[2])
    voxelsize=str(himg.get_zooms()[0])+'mm x'+str(himg.get_zooms()[1])+'mm x'+str(himg.get_zooms()[2])+'mm'
    tr=str(himg.get_zooms()[-1])
    if findspace == -1:
        structrun=str('FMRIPREP')
    else:
        structrun=str('xcpEngine')

elif 'cbf' in modules1:
    funct='ASL'
    imagetype='Functional'
    himg=load_img(outdir+'/prestats/'+prefix+'_preprocessed.nii.gz').header
    nvols=str(himg.get_data_shape()[-1])
    Dim=str(himg.get_data_shape()[0]) +'x'+ str(himg.get_data_shape()[1])+'x'+str(himg.get_data_shape()[2])
    voxelsize=str(himg.get_zooms()[0])+'mm x'+str(himg.get_zooms()[1])+'mm x'+str(himg.get_zooms()[2])+'mm'
    tr=str(himg.get_zooms()[-1])
    if findspace != -1:
        structrun=str('FMRIPREP')
    else:
        structrun=str('xcpEngine')
elif 'struc' in modules1:
    funct='N/A'
    imagetype='Structural'
    nvols=str(1)
    himg=load_img(outdir+'/struc/'+prefix+'_ExtractedBrain0N4.nii.gz').header
    Dim=str(himg.get_data_shape()[0]) +'x'+ str(himg.get_data_shape()[1])+'x'+str(himg.get_data_shape()[2])
    voxelsize=str(himg.get_zooms()[0])+'mm x'+str(himg.get_zooms()[1])+'mm x'+str(himg.get_zooms()[2])+'mm'
    tr=str(himg.get_zooms()[-1])
    structrun=str('xcpEngine')


templatelabel = open(outdir+'/template.txt', 'r').read()

subjectsummary='\
<ul class="elem-desc"> \
<li>Subject ID: '+prefix+' </li> \
<li>Image type: '+imagetype+' </li> \
<li>Functional series: '+funct+'</li> \
<li>Number of volumes: '+nvols+'</li>\
<li>Volume dimension: '+Dim+'</li>\
<li>Voxel size: '+voxelsize+'</li>\
<li>Repetition time (TR): '+tr+'s</li>\
<li>Template: '+templatelabel+' </li> \
<li>Anatomical source: '+structrun+'</li> \
</ul> '




qcfile=outdir+'/'+prefix+'_quality.csv'
qc=pd.read_csv(qcfile)
removec=qc.columns[ qc.columns.str.startswith('id')]
qc=qc.drop(removec,axis='columns')

motion_qc=['relMeanRMSMotion','relMaxRMSMotion','meanDV','pctSpikesDV','nSpikesFD','pctSpikesFD']
functreg_qc=['coregCrossCorr','coregJaccard','coregDice','coregCoverage']
struct_qc=['regCoverage','regCrossCorr','regDice','regJaccard','meanGMD']
reg_qc=['nNuisanceParameters','nVolCensored','estimatedLostTemporalDOF','motionDVCorrInit','motionDVCorrFinal']
cbf_qc=['cbf_qei','negativeVoxelsTS','negativeVoxels','cbfscore_qei','nvoldel','cbfscrub_qei','cbfspatial_qei','cbfbasil_qei','negativeVoxels_basil	','cbfpv_qei']
regstotemp_qc=['normJaccard','normDice','normCrossCorr','normCoverage']




#df = pd.DataFrame(qc,columns=qc_required).dropna(axis='columns')
motionqc=pd.DataFrame(qc,columns=motion_qc).dropna(axis='columns'); motionhtml=motionqc.to_html(index=False)
functqc=pd.DataFrame(qc,columns=functreg_qc).dropna(axis='columns'); funcreghtml=functqc.to_html(index=False)
strucqc=pd.DataFrame(qc,columns=struct_qc).dropna(axis='columns'); struchtml=strucqc.to_html(index=False)
regqc=pd.DataFrame(qc,columns=reg_qc).dropna(axis='columns'); reghtml=regqc.to_html(index=False)
cbfqc=pd.DataFrame(qc,columns=cbf_qc).dropna(axis='columns'); cbfhtml=cbfqc.to_html(index=False)
normqc=pd.DataFrame(qc,columns=regstotemp_qc).dropna(axis='columns'); normhtml=normqc.to_html(index=False)






html_table = qc.to_html(index=False)


html_report=' \
    <head> <meta http-equiv="Content-Type" content="text/html; charset=utf-8" /> <meta name="generator" content="Docutils 0.12: http://docutils.sourceforge.net/" /> <title></title>  \
    <script src="https://code.jquery.com/jquery-3.3.1.slim.min.js" integrity="sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo" crossorigin="anonymous"></script> \
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/js/bootstrap.min.js" integrity="sha384-ChfqqxuZUCnJSK3+MXmPNIyE6ZbWh2IMqE241rYiqJxyMiZ6OW/JmZQ5stwEULTy" crossorigin="anonymous"></script> \
    <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css" integrity="sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO" crossorigin="anonymous"> \
    <style type="text/css"> .sub-report-title {} .run-title {}  \
     h1 { padding-top: 15px; } h2 { padding-top: 10px; } h3 { padding-top: 5px; }\
    div.elem-image {width: 100%;page-break-before:always;} .elem-image object.svg-reportlet {,width: 100%; padding-bottom: 5px; },body {padding: 65px 10px 10px;} .boiler-html {font-family: "Bitstream Charter", "Georgia", Times;="htmargin: 20px 25px;padding: 10px; background-color: #F8F9FA;} \
    div#boilerplate pre {margin: 20px 25px;padding: 10px;mbackground-color: #F8F9FA;} </style> </head>'

#html_report='<html> <head> <h1> xcpEngine report </h1>  </head> <body> <h2> Modules: ' + modulelist + '</h2> <h2> QC </h2> ' + html_table + '' 
html_report= '<body> <div id="Summary">   <h1 class="sub-report-title">Summary</h1> ' + subjectsummary + '</div> ' 

if 'regress' in modules1: 
    html_report=html_report+'<div id="Quality control">   <h2 class="sub-report-title">Quality control</h2> ' + funcreghtml +'<br>'+ motionhtml+'<br>'+reghtml+'<br>'+ normhtml+ '</div> '
elif 'cbf' in modules1:
    html_report=html_report+'<div id="Quality control">   <h2 class="sub-report-title">Quality control</h2> ' + funcreghtml +'<br>'+ motionhtml +'<br>'+ cbfhtml +'<br>'+ normhtml +'</div> '
elif 'struc' in modules1:
    html_report=html_report+'<div id="Quality control">   <h2 class="sub-report-title">Quality control</h2> ' + struchtml +'<br>'+cbfhtml+'<br>'+ normhtml +'</div> ' 


#modules=modules.drop(['qcanat'],axis=1)
for i in modules1:
    if i == 'struc':
        fig = plt.figure(constrained_layout=False,figsize=(20,10))
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
        cuts=cuts_from_bbox(mask_nii=mask,cuts=5)
        f1=plot_registration(moving,'fixed-image',cuts=cuts,label='Extracted Brain')
        f2=plot_registration(load_img(template),'moving-image',cuts=cuts,label='Template')
        compose_view(f1,f2,out_file=outdir+'/figures/'+prefix+'_registration.svg')
        structreg='figures/'+prefix+'_registration.svg'
        html_report=html_report+'<p <p>'
        html_report=html_report+'<div id="struc">  </div>  </ul><h2 class="elem-title">Brain mask and brain tissue segmentation of the T1w</h2><p class="elem-desc"> \
                  This panel shows the template T1-weighted image, with contours delineating the detected brain mask and brain tissue segmentations.<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+segplot+ '">filename:'+segplot+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+segplot+ '" target="_blank">' +segplot+ '</a> </div> ' 
        html_report=html_report+'<p <p>'
        html_report=html_report+'<div id="struc1">  </div>  </ul><h2 class="elem-title">T1w to Template registration</h2><p class="elem-desc">Nonlinear mapping of the T1w image into Template space.\
                             Hover on the panel with the mouse to transition between both spaces.<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+structreg+ '">filename:'+structreg+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+structreg+ '" target="_blank">' +structreg+ '</a> </div> ' 
        html_report=html_report+'<p <p>'
  
        #html_report=html_report + '<h1> struc module </h1> <h3> Brain segmentation </h3>  <p>Extracted brain with segmented tissues (contours).</p>  <img src="'+ segplot + '" alt="Segmentation" width="2000"height="800"> \
        #<h3> Registration </h3> <p>T1w registered to the  template .</p>  <object type="image/svg+xml" data="'+ structreg + '" alt="Segmentation" width="2000"height="800"></object>'
    elif i == 'jlf':
         jlf_label=load_img(outdir+'/jlf/'+prefix+'_Labels.nii.gz')
        
         plot_epi(epi_img=jlf_label,output_file=outdir+'/figures/'+prefix+'_label.svg',display_mode='z',cut_coords=7,draw_cross=False,title='JLF atlas')
         jflplot='figures/'+prefix+'_label.svg'
         html_report=html_report+'<div id="jlf"> </div>  </ul><h3 class="elem-title">Joint Label Fusion</h3><p class="elem-desc"> Anatomical parcellation based on the openly available set of \
              OASIS challenge labels.<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+jflplot+ '">filename:'+jflplot+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+jflplot+ '" target="_blank">' +jflplot+ '</a> </div> ' 
         
        # html_report=html_report + '<h1> jlf module </h1> <h3> JLF attlas  </h3> <object type="image/svg+xml" data="'+ jflplot + '" alt="Segmentation" width="2000"height="800"></object>'
    elif i == 'prestats':
         fig = plt.figure(constrained_layout=False,figsize=(20,10))
         checkfile = os.path.isfile(outdir+'/prestats/'+prefix+'_segmentation.nii.gz')
         if checkfile:
            moving=load_img(outdir+'/prestats/'+prefix+'_referenceVolumeBrain.nii.gz')
            fixedim=load_img(outdir+'/prestats/'+prefix+'_structbrain.nii.gz')
            mask=threshold_img(moving,1e-3)
            cuts=cuts_from_bbox(mask_nii=mask,cuts=5)
            f1=plot_registration(moving,'fixed-image',cuts=cuts,label='moving')
            f2=plot_registration(fixedim,'moving-image',cuts=cuts,label='fixed')
            compose_view(f1,f2,out_file=outdir+'/figures/'+prefix+'_registration.svg')
            fmreg='figures/'+prefix+'_registration.svg'
            
            html_report=html_report+'<div id="prestats"> </ul><h3 class="elem-title"> Functional data registration/transformation from EPI-space to T1w-space</h3> \
                <p class="elem-desc"> Overlap of the functional data and T1w in T1w space.<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+fmreg+ '">filename:'+fmreg+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href=".'+fmreg+ '" target="_blank">' +fmreg+ '</a> </div> ' 
           
            #html_report=html_report + '<h1> prestats module </h1> <h3> Co-registration </h3> <p> Functional registration to Structural .</p> <object type="image/svg+xml" data="'+ fmreg+ '" alt="Segmentation" width="2000"height="800"></object>'

    #elif i == 'regress':
         #not using it now but will be needed later i hope 
        # segm=outdir+'/prestats/'+prefix+'_segmentation.nii.gz'
         #seg_data=load_img(segm).get_data()
         #resid=outdir+'regress/'+prefix+'_residualised.nii.gz'
         #tr=nib.load(resid).header['pixdim'][4]
         #plot_carpet(img=resid,atlaslabels=seg_data,tr=tr,output_file=outdir+'/regress/'+prefix+'_residualized.svg')
         #residplot='regress/'+prefix+'_residualized.svg'
         #html_report=html_report + '<h1> regress module </h1> <h3> Residualized BOLD data </h3> <object type="image/svg+xml" data="'+ residplot +'" alt="Segmentation" width="1000"height="800"></object>'
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
         font = {
        'weight': 'normal',
        'size': 10}
         if (len(atlaslist) == 1 ) :
              plt.clf()#ii=atlaslist[0]
              plt.cla()
              fig,ax1 = plt.subplots(1,1)
              #fig.set_size_inches(500,500)
              tms=np.loadtxt(outdir+'/fcon/'+atlaslist[-1]+'/'+prefix+'_'+atlaslist[-1]+'_ts.1D')
              cormatrix=np.nan_to_num(np.corrcoef(tms.T))
              ax1.set_title(atlaslist[-1],fontdict=font)
              plot_matrix(mat=cormatrix,colorbar=False,vmax=1,vmin=-1,axes=ax1)
              fig.savefig(outdir+'/figures/'+prefix+'_corrplot.svg',bbox_inches="tight",pad_inches=None)
              corrplot='figures/'+prefix+'_corrplot.svg'
              html_report=html_report + '<h1> fcon module </h1> <h3> Functional connectivity matrices  </h3> <object type="image/svg+xml" data="'+ corrplot +'" alt="Segmentation" width="500"height="500"></object>'
         else :      
              ng=0         
              np1=len(atlaslist)
              plt.clf()#ii=atlaslist[0]
              plt.cla()
              fig = plt.figure()
              fig,ax1 = plt.subplots(1,np1)
              fig.set_size_inches(50,50)
              font = {
                'weight': 'normal',
               'size': 20}
              for ii in atlaslist:
                  tms=np.loadtxt(outdir+'/fcon/'+ii+'/'+prefix+'_'+ii+'_ts.1D')
                  cormatrix=np.nan_to_num(np.corrcoef(tms.T))
                  axs=ax1[ng]
                  axs.set_title(ii,fontdict=font)
                  plot_matrix(mat=cormatrix,colorbar=False,vmax=1,vmin=-1,axes=axs)
                  ng +=1

              fig.savefig(outdir+'/figures/'+prefix+'_corrplot.svg',bbox_inches="tight",pad_inches=None)
              corrplot='figures/'+prefix+'_corrplot.svg'
              
              html_report=html_report+'<div id="fcon"></div>  </ul><h2 class="elem-title">Functional Connectivity</h2><p class="elem-desc"> Functional connectvity matrices with the atlases.<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+corrplot + '">filename:'+corrplot+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href=".'+ corrplot + '" target="_blank">' +corrplot + '</a> </div> ' 

              #html_report=html_report + '<h1> fcon module </h1> <h3> Functional connectivity matrices  </h3> <object type="image/svg+xml" data="'+ corrplot +'" alt="Segmentation" width="4000"height="500"></object>'

    elif i == 'alff' :
         fig = plt.figure(constrained_layout=False,figsize=(30,15))
         statmapalff=load_img(outdir+'/alff/'+prefix+'_alffZ.nii.gz')
         bgimg=load_img(outdir+'/prestats/'+prefix+'_referenceVolumeBrain.nii.gz')
         plot_stat_map(stat_map_img=statmapalff,bg_img=bgimg,display_mode='z',cut_coords=7,draw_cross=False,vmax=2,
              symmetric_cbar=True,colorbar=True,black_bg=False,output_file=outdir+'/figures/'+prefix+'_alff.svg')
         alffplot='figures/'+prefix+'_alff.svg'
         
         html_report=html_report+'<div id="alff">   </div>  </ul><h2 class="elem-title"> Amplitude of low-frequency fluctuations</h2><p class="elem-desc"> \
                      amplitude of low-frequency fluctuations obtained from regresed BOLD data.<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+ alffplot + '">filename:'+alffplot+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href=".'+ alffplot + '" target="_blank">' +alffplot + '</a> </div> '


         #html_report=html_report + '<h1> alff module </h1> <object type="image/svg+xml" data="'+ alffplot +'" alt="Segmentation" width="2000"height="400"></object>'
    elif i == 'reho' :
         fig = plt.figure(constrained_layout=False,figsize=(30,10))
         statmapreho=load_img(outdir+'/reho/'+prefix+'_rehoZ.nii.gz')
         bgimg=load_img(outdir+'/prestats/'+prefix+'_referenceVolumeBrain.nii.gz')
         plot_stat_map(stat_map_img=statmapreho,bg_img=bgimg,display_mode='z',cut_coords=7,draw_cross=False,vmax=2,
              symmetric_cbar=True,colorbar=True,black_bg=False,output_file=outdir+'/figures/'+prefix+'_reho.svg')
         rehoplot='figures/'+prefix+'_reho.svg'
         html_report=html_report+'<div id="reho">  </div>  </ul><h2 class="elem-title"> regional homogeneity </h2><p class="elem-desc"> \
                      regional homogeneity maps using Kendall coefficient of concordance over voxel neighbourhoods.<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+ rehoplot + '">filename:'+rehoplot+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href=".'+ rehoplot + '" target="_blank">' +rehoplot + '</a> </div> '
         #html_report=html_report + '<h1> reho module </h1> <object type="image/svg+xml" data="'+ rehoplot +'" alt="Segmentation" width="2000"height="400"></object>'
    elif i == 'norm' :
           #fig = plt.figure(constrained_layout=False,figsize=(20,10))
           moving=os.path.isfile(outdir+'/norm/'+prefix+'_referenceVolumeBrainStd.nii.gz')
           if moving: 
               moving=load_img(outdir+'/norm/'+prefix+'_referenceVolumeBrainStd.nii.gz')
           else :
               moving=load_img(outdir+'/norm/'+prefix+'_intensityStd.nii.gz')
           fig = plt.figure(constrained_layout=False,figsize=(30,15))
           mask=threshold_img(moving,1e-3)
           cuts=cuts_from_bbox(mask_nii=mask,cuts=7)
           f1=plot_registration(moving,'fixed-image',cuts=cuts,label='moving')
           f2=plot_registration(load_img(template),'moving-image',cuts=cuts,label='fixed')
           compose_view(f1,f2,out_file=outdir+'/figures/'+prefix+'_normalization.svg')
           normreg='figures/'+prefix+'_normalization.svg'
            
           html_report=html_report+'<div id="norm">  </div>  </ul><h3 class="elem-title"> Functional normalization to Template </h3><p class="elem-desc"> \
                      Normalization of Functional data through T1w space to Template space .<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+ normreg + '">filename:'+normreg+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+ normreg+ '" target="_blank">' +normreg + '</a> </div> '


           #html_report=html_report + '<h1> norm module </h1>  <p> <h3> Functional normalization to the Template </h3> <p> <object type="image/svg+xml" data="'+ normreg + '" alt="Segmentation" width="2000"height="800"></object>'
    elif i == 'coreg':
           fig = plt.figure(constrained_layout=False,figsize=(30,15))
           moving=load_img(outdir+'/coreg/'+prefix+'_seq2struct.nii.gz')
           fixedim=load_img(outdir+'/coreg/'+prefix+'_target.nii.gz')
           mask=threshold_img(moving,1e-3)
           cuts=cuts_from_bbox(mask_nii=mask,cuts=7)
           f1=plot_registration(moving,'fixed-image',cuts=cuts,label='moving')
           f2=plot_registration(fixedim,'moving-image',cuts=cuts,label='fixed')
           compose_view(f1,f2,out_file=outdir+'/figures/'+prefix+'_registration.svg')
           natreg='figures/'+prefix+'_registration.svg'

           html_report=html_report+'<div id="coreg"> </div>  </ul><h2 class="elem-title">Functional registration T1w space </h2><p class="elem-desc"> Functional data registration/transformation from EPI-space to T1w-space.<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+ natreg+ '">filename:'+natreg+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+ natreg + '" target="_blank">' +natreg + '</a> </div>'
           #html_report=html_report + '<h1> coreg module </h1>  <p> <h3> Coregistration of T1w and Fucntional image </h3> <p> <object type="image/svg+xml" data="'+ natreg + '" alt="Segmentation" width="2000"height="800"></object>'

    elif i == 'cbf' :
          statmapcbf=load_img(outdir+'/cbf/'+prefix+'_cbf.nii.gz')
          cbfts=load_img(outdir+'/cbf/'+prefix+'_cbf_ts.nii.gz')
          bgimg=load_img(outdir+'/prestats/'+prefix+'_referenceVolumeBrain.nii.gz')
          mask=load_img(outdir+'/coreg/'+prefix+'_mask.nii.gz').get_fdata()
          imgdata=load_img(outdir+'/cbf/'+prefix+'_cbf.nii.gz').get_fdata(); logmask=np.isclose(mask, 1); dat1=imgdata[logmask]
          tagmask=np.loadtxt(outdir+'/cbf/'+prefix+'_tag_mask.txt')
          relrms=np.loadtxt(outdir+'/prestats/mc/'+prefix+'_relRMS.1D')
          combinerel=np.mean(np.array([relrms[tagmask==1],relrms[tagmask==0]]),axis=0)
          gm=load_img(outdir+'/coreg/'+prefix+'_gm2seq.nii.gz');gm=threshold_img(gm,0.8)
          gm = math_img('img > 0.8', img=gm);gmask=np.isclose(gm.get_fdata(), 1);gmask=gmask[:,:,:,-1]
          wm=load_img(outdir+'/coreg/'+prefix+'_wm2seq.nii.gz');wm=threshold_img(wm,0.8)
          wm = math_img('img > 0.8', img=wm);wmask=np.isclose(wm.get_fdata(), 1);wmask=wmask[:,:,:,-1]
          csf=load_img(outdir+'/coreg/'+prefix+'_csf2seq.nii.gz');csf=threshold_img(csf,0.8)
          cm = math_img('img > 0.8', img=csf);cmask=np.isclose(cm.get_fdata(), 1);cmask=cmask[:,:,:,-1]
          cbf_ts=cbfts.get_fdata()
          gb=np.mean(cbf_ts[gmask],axis=0);wb=np.mean(cbf_ts[wmask],axis=0);cb=np.mean(cbf_ts[cmask],axis=0)
          tr=cbfts.header.get_zooms()[-1]; seg=gmask+wmask*2+cmask*3
          plt.clf()#ii=atlaslist[0]
          plt.cla()
          fig= plt.gcf()
          fig = plt.figure(constrained_layout=False,figsize=(30,15))
          #fig.clear()
          grid = mgs.GridSpec(5, 1, wspace=0.0, hspace=0.05,height_ratios=[1.5] * (5 - 1) + [5])
          confoundplot(combinerel, grid[0], tr=tr/2, color='b',name='FD',units='mm')
          confoundplot(gb, grid[1], tr=tr/2, color='r',name='GM_CBF')
          confoundplot(wb, grid[2], tr=tr/2, color='g',name='WM_CBF')
          confoundplot(cb, grid[3], tr=tr/2, color='b',name='CSF_CBF')
          plot_carpet(cbfts,seg, subplot=grid[-1],tr=tr/2)
          fig.savefig(outdir+'/figures/'+prefix+'_cbf1.svg',bbox_inches="tight",pad_inches=None)
          cbf1=outdir+'/figures/'+prefix+'_cbf1.svg'
          #prestatsfig='figures/'+prefix+'_prestats.svg'
          fig= plt.gcf()
          plot_stat_map(stat_map_img=statmapcbf,bg_img=bgimg,display_mode='z',cut_coords=5,draw_cross=False,vmax=99,
              symmetric_cbar=True,colorbar=True,black_bg=True,output_file=outdir+'/figures/'+prefix+'_cbf2.svg')
          cbf2=outdir+'/figures/'+prefix+'_cbf2.svg'
          data=statmapcbf.get_fdata(); dat=[data[wmask==1],data[gmask==1]]; 
          fig= plt.gcf()
          fig = plt.figure(constrained_layout=False,figsize=(30,10))
          gs1 = fig.add_gridspec(nrows=3, ncols=3, left=0.05, right=0.48, wspace=0.5)
          ax1 = fig.add_subplot(gs1[-1, :-1])
          ax2 = fig.add_subplot(gs1[-1, -1])
          #sns.set(style="white", palette="bright", color_codes=True,font_scale=1.)
          sns.distplot(dat1,kde=False,ax=ax1,color='b'); ax1.title.set_text('CBF distribution')
          ax2.violinplot(dat); labels={'GM','WM'}; ax2.set_xticks([1,2])
          ax2.set_xticklabels(labels); ax1.set_ylabel('No of Voxel', fontsize = 20.0); 
          ax1.set_xlabel('CBF ml/min/100g', fontsize = 20); ax2.set_ylabel('CBF ml/min/100g', fontsize = 20)
          fig.savefig(outdir+'/figures/'+prefix+'_cbf3.svg',bbox_inches="tight",pad_inches=None)
          cbf3=outdir+'/figures/'+prefix+'_cbf3.svg'

          html_report=html_report+'<div id="cbf">  </div>  </ul><h2 class="elem-title"> Arterial Spin Labeling/Perfusion</h2><p class="elem-desc"> The first panel plotted the summary statistics that may reveal \
              trends or artifacts in the ASL data. FD shows the avereage of framewise displacement of label and control. Others are the CBF computed within grey matter (GM), white matter (WM) and cerebrospinal fluid (CSF). \
                The carpet plot shows the CBF times series. The second panel shows the plot of CBF and the last pabel shows the distribution of CBF within the whole brain mask and  boxplot of CBF in GM and WM voxels   .<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+cbf1+ '">filename:'+cbf1+ '</object> \
                     </div> <div class="elem-filename"> Get figure file: <a href="'+ cbf1 + '" target="_blank">' +cbf1+ '</a> </div>'

          html_report=html_report+' <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+cbf2+ '">filename:' +cbf2+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+cbf2+'" target="_blank">' +cbf2+  '</a> </div> ' 

          html_report=html_report+' <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+cbf3+ '">filename:' +cbf3+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+cbf3+'" target="_blank">' +cbf3+  '</a> </div> ' 
          fig.clear()
         #html_report=html_report + '<h1> cbf module <h1> <object type="image/svg+xml" data="'+ cbfplot + '" alt="Segmentation" width="2000"height="400"></object>'

    elif i == 'basil' :
          statmapcbf=load_img(outdir+'/basil/'+prefix+'_cbfbasil.nii.gz')
          bgimg=load_img(outdir+'/prestats/'+prefix+'_referenceVolumeBrain.nii.gz')
          gm=load_img(outdir+'/coreg/'+prefix+'_gm2seq.nii.gz');gm=threshold_img(gm,0.8)
          gm = math_img('img > 0.8', img=gm);gmask=np.isclose(gm.get_fdata(), 1);gmask=gmask[:,:,:,-1]
          wm=load_img(outdir+'/coreg/'+prefix+'_wm2seq.nii.gz');wm=threshold_img(wm,0.8)
          wm = math_img('img > 0.8', img=wm);wmask=np.isclose(wm.get_fdata(), 1);wmask=wmask[:,:,:,-1]
          csf=load_img(outdir+'/coreg/'+prefix+'_csf2seq.nii.gz');csf=threshold_img(csf,0.8)
          cm = math_img('img > 0.8', img=csf); cmask=np.isclose(cm.get_fdata(), 1); cmask=cmask[:,:,:,-1]
          fig= plt.gcf()
          plot_stat_map(stat_map_img=statmapcbf,bg_img=bgimg,display_mode='z',cut_coords=5,draw_cross=False,vmax=99,
              symmetric_cbar=True,colorbar=True,black_bg=True,output_file=outdir+'/figures/'+prefix+'_basil1.svg')
          basil1=outdir+'/figures/'+prefix+'_basil1.svg'

          data=statmapcbf.get_fdata(); dat=[data[wmask==1],data[gmask==1]]; 
          #sns.set(style="white", palette="bright", color_codes=True,font_scale=2)
          fig= plt.gcf()
          fig = plt.figure(constrained_layout=False,figsize=(30,15))
          gs1 = fig.add_gridspec(nrows=3, ncols=3, left=0.05, right=0.48, wspace=0.5)
          ax1 = fig.add_subplot(gs1[-1, :-1])
          ax2 = fig.add_subplot(gs1[-1, -1])
          #sns.set(style="white", palette="bright", color_codes=True,font_scale=1.5)
          sns.distplot(dat1,kde=False,ax=ax1,color='b'); ax1.title.set_text('CBF basil distribution')
          ax2.violinplot(dat); labels={'GM','WM'}; ax2.set_xticks([1,2])
          ax2.set_xticklabels(labels); ax1.set_ylabel('No of Voxel', fontsize = 20.0); 
          ax1.set_xlabel('CBF ml/min/100g', fontsize = 20); ax2.set_ylabel('CBF  ml/min/100g', fontsize = 20)
          fig.savefig(outdir+'/figures/'+prefix+'_basil2.svg',bbox_inches="tight",pad_inches=None)
          basil2=outdir+'/figures/'+prefix+'_basil2.svg'
          fig.clear()
          html_report=html_report+'<div id="basil">  </div>  </ul><h2 class="elem-title"> Bayesian Inference for Arterial Spin Labelling MRI </h2><p class="elem-desc"> BASIL provides various advantages including spatial  \
                regularization of the estimated perfusion image and correction of partial volume effects. The  first panel shows the CBF plot  and last pabel shows the distribution  \
                     of CBF within the whole brain mask and  boxplot of CBF in GM and WM voxels  <p><br />   \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+basil1+ '">filename:'+basil1+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href=" '+ basil1 + '" target="_blank">' + basil1 + '</a> </div>'
              
          html_report=html_report+' <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+basil2+ '">filename:' +basil2+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+basil2+'" target="_blank">' +basil2+  '</a> </div> ' 
         
        #html_report=html_report + '<h1> basil module </h1>  <object type="image/svg+xml" data="'+ basilplot + '" alt="Segmentation" width="2000"height="400"></object>'
          fig.clear()
    elif i == 'scorescrub' :
          statmapcbf=load_img(outdir+'/scorescrub/'+prefix+'_cbfscore.nii.gz')
          cbfts=load_img(outdir+'/scorescrub/'+prefix+'_cbfscore_ts.nii.gz')
          bgimg=load_img(outdir+'/prestats/'+prefix+'_referenceVolumeBrain.nii.gz')
          mask=load_img(outdir+'/coreg/'+prefix+'_mask.nii.gz').get_fdata()
          imgdata=load_img(outdir+'/scorescrub/'+prefix+'_cbfscore.nii.gz').get_fdata(); logmask=np.isclose(mask, 1); dat1=imgdata[logmask]
          tagmask=np.loadtxt(outdir+'/cbf/'+prefix+'_tag_mask.txt')
          relrms=np.loadtxt(outdir+'/prestats/mc/'+prefix+'_relRMS.1D')
          combinerel=np.mean(np.array([relrms[tagmask==1],relrms[tagmask==0]]),axis=0)
          #volindex=np.loadtxt(outdir+'/scorescrub/'+prefix+'_nvoldel.txt')
          #newcombinerel=combinerel[]
          gm=load_img(outdir+'/coreg/'+prefix+'_gm2seq.nii.gz');gm=threshold_img(gm,0.8)
          gm = math_img('img > 0.8', img=gm);gmask=np.isclose(gm.get_fdata(), 1);gmask=gmask[:,:,:,-1]
          wm=load_img(outdir+'/coreg/'+prefix+'_wm2seq.nii.gz');wm=threshold_img(wm,0.8)
          wm = math_img('img > 0.8', img=wm);wmask=np.isclose(wm.get_fdata(), 1);wmask=wmask[:,:,:,-1]
          csf=load_img(outdir+'/coreg/'+prefix+'_csf2seq.nii.gz');csf=threshold_img(csf,0.8)
          cm = math_img('img > 0.8', img=csf); cmask=np.isclose(cm.get_fdata(), 1); cmask=cmask[:,:,:,-1]
          cbf_ts=cbfts.get_fdata()
          gb=np.mean(cbf_ts[gmask],axis=0);wb=np.mean(cbf_ts[wmask],axis=0);cb=np.mean(cbf_ts[cmask],axis=0)
          tr=cbfts.header.get_zooms()[-1]; seg=gmask+wmask*2+cmask*3
          plt.clf()#ii=atlaslist[0]
          plt.cla()
          fig= plt.gcf()
          fig = plt.figure(constrained_layout=False,figsize=(30,15))
          grid = mgs.GridSpec(5, 1, wspace=0.0, hspace=0.05,height_ratios=[1.5] * (5 - 1) + [5])
          confoundplot(combinerel, grid[0], tr=tr/2, color='b',name='FD',units='mm')
          confoundplot(gb, grid[1], tr=tr/2, color='r',name='GM_CBF')
          confoundplot(wb, grid[2], tr=tr/2, color='g',name='WM_CBF')
          confoundplot(cb, grid[3], tr=tr/2, color='b',name='CSF_CBF')
          plot_carpet(cbfts,seg, subplot=grid[-1],tr=tr/2)
          fig.savefig(outdir+'/figures/'+prefix+'_score1.svg',bbox_inches="tight",pad_inches=None)
          score1=outdir+'/figures/'+prefix+'_score1.svg'
          #prestatsfig='figures/'+prefix+'_prestats.svg'
          fig= plt.gcf()
          plot_stat_map(stat_map_img=statmapcbf,bg_img=bgimg,display_mode='z',cut_coords=5,draw_cross=False,vmax=99,
              symmetric_cbar=True,colorbar=True,black_bg=True,output_file=outdir+'/figures/'+prefix+'_score2.svg')
          score2=outdir+'/figures/'+prefix+'_score2.svg'
           
          data=statmapcbf.get_fdata(); dat=[data[wmask==1],data[gmask==1]]; 
          #sns.set(style="white", palette="bright", color_codes=True,font_scale=1.5)
          fig= plt.gcf()
          fig = plt.figure(constrained_layout=False,figsize=(30,15))
          gs1 = fig.add_gridspec(nrows=3, ncols=3, left=0.05, right=0.48, wspace=0.5)
          ax1 = fig.add_subplot(gs1[-1, :-1])
          ax2 = fig.add_subplot(gs1[-1, -1])
          #sns.set(style="white", palette="bright", color_codes=True,font_scale=2)
          sns.distplot(dat1,kde=False,ax=ax1,color='b'); ax1.title.set_text('CBF score distribution')
          ax2.violinplot(dat); labels={'GM','WM'}; ax2.set_xticks([1,2])
          ax2.set_xticklabels(labels); ax1.set_ylabel('No of Voxel', fontsize = 20.0); 
          ax1.set_xlabel('CBF ml/min/100g', fontsize = 20); ax2.set_ylabel('CBF  ml/min/100g', fontsize = 20)
          fig.savefig(outdir+'/figures/'+prefix+'_score3.svg',bbox_inches="tight",pad_inches=None)
          score3=outdir+'/figures/'+prefix+'_score3.svg'
          scrubcbf=load_img(outdir+'/scorescrub/'+prefix+'_cbfscrub.nii.gz')
        
          fig= plt.gcf()
          plot_stat_map(stat_map_img=scrubcbf,bg_img=bgimg,display_mode='z',cut_coords=5,draw_cross=False,vmax=99,
              symmetric_cbar=True,colorbar=True,black_bg=True,output_file=outdir+'/figures/'+prefix+'_scrub1.svg')
          scrub1=outdir+'/figures/'+prefix+'_scrub1.svg'
           
          data=scrubcbf.get_fdata(); dat=[data[wmask==1],data[gmask==1]]; 
          #sns.set(style="white", palette="bright", color_codes=True,font_scale=1.5)
          fig= plt.gcf()
          fig = plt.figure(constrained_layout=False,figsize=(30,15))
          gs1 = fig.add_gridspec(nrows=3, ncols=3, left=0.05, right=0.48, wspace=0.5)
          ax1 = fig.add_subplot(gs1[-1, :-1])
          ax2 = fig.add_subplot(gs1[-1, -1])
          #sns.set(style="white", palette="bright", color_codes=True,font_scale=2)
          sns.distplot(dat1,kde=False,ax=ax1,color='b'); ax1.title.set_text('CBF scrub distribution')
          ax2.violinplot(dat); labels={'GM','WM'}; ax2.set_xticks([1,2])
          ax2.set_xticklabels(labels); ax1.set_ylabel('No of Voxel', fontsize = 20.0); 
          ax1.set_xlabel('CBF ml/min/100g', fontsize = 20); ax2.set_ylabel('CBF  ml/min/100g', fontsize = 20)
          fig.savefig(outdir+'/figures/'+prefix+'_scrub2.svg',bbox_inches="tight",pad_inches=None)
          scrub2=outdir+'/figures/'+prefix+'_scrub2.svg'
        
          html_report=html_report+'<div id="scorescrub">  </div>  </ul><h2 class="elem-title"> CBF  Structural Correlation with RobUst Bayesian and Outlier Rejection (scorescrub)\
                    </h2><p class="elem-desc"> \
                 The first panel plotted the summary statistics that may reveal trends or artifacts in the ASL data after the oullier voulmes has beed removed.  \
                  FD shows the avereage of framewise displacement of label and control. Others are the CBF computed within grey matter (GM), white matter (WM) and cerebrospinal fluid (CSF). \
                 The carpet plot shows the CBF times series without outlier volumes. The second panel shows the plot of CBF and the third  pabel shows the distribution of CBF within the whole  \
                 brain mask and  boxplot of CBF in GM and WM voxels. The fourth panel shows the CBF estimated with  robust Bayesian method and last panel  \
                     shows the distribution of CBF within the whole  brain mask and  boxplot of CBF in GM and WM voxels. .<p><br />    \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+score1+ '">filename:'+score1+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+score1+ '" target="_blank">' +score1+ '</a> </div> ' 

          html_report=html_report+' <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+score2+ '">filename:'+score2+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+score2+'" target="_blank">' +score2+ '</a> </div> ' 

          html_report=html_report+' <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+score3+ '">filename:'+score3+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+score3+'" target="_blank">' +score3+ '</a> </div> ' 

          html_report=html_report+' <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+scrub1+ '">filename:'+scrub1+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+scrub1+'" target="_blank">' +scrub1+ '</a> </div> ' 

          html_report=html_report+' <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+scrub2+ '">filename:'+scrub2+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+scrub2+'" target="_blank">' +scrub2+ '</a> </div> ' 
         #html_report=html_report + '<h1> scorescrub module <h1> <object type="image/svg+xml" data="'+ scoreplot + '" alt="Segmentation" width="2000"height="400"></object> \
            # <h3> </h3> <p> </p> </h3>  <p> <p>   <object type="image/svg+xml" data="'+ scrubplot + '" alt="Segmentation" width="2000"height="400"></object>'
          fig.clear()
    elif i == 'roiquant' :
         # not using for now 
         filejson=outdir+'/'+prefix+'_atlas/'+prefix+'_atlas.json'
         with open(filejson, 'r') as atlasfile:
              data_atlas=atlasfile.read()

         objatlas = json.loads(data_atlas)
         atlaslist=[]
         for k in objatlas .keys():
             atlaslist.append(k)
         atlasused=ulify(atlaslist)
         html_report=html_report + '<h1> roiquant module </h1> <h3> The atlas used: ' + atlasused +' </h3> ' 
    elif i == 'task' :
         os.system('cp  '+ outdir+'/task/fsl/'+prefix+'.feat/design.png '  +outdir+'/figures/'+prefix+'_taskdesign.png')
         taskdeign=outdir+'/figures/'+prefix+'_taskdesign.png'
         moving=load_img(outdir+'/task/'+prefix+'_referenceVolumeBrain.nii.gz')
         fixedim=load_img(outdir+'/task/'+prefix+'_struct.nii.gz')
         mask=threshold_img(moving,1e-3)
         cuts=cuts_from_bbox(mask_nii=mask,cuts=7)
         f1=plot_registration(moving,'fixed-image',cuts=cuts,label='functional')
         f2=plot_registration(fixedim,'moving-image',cuts=cuts,label='structural')
         compose_view(f1,f2,out_file=outdir+'/figures/'+prefix+'_taskregistration.svg')
         taskreg='figures/'+prefix+'_taskregistration.svg'
         
         html_report=html_report+'<div id="task">  </div>  </ul><h2 class="elem-title">FSL FEAT processing of task data. \
                    </h2><p class="elem-desc"> \
                 The first  panel shows task registration to T1w space. The second panel shows the task deisgns .<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+taskreg+ '">filename:'+taskreg+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+taskreg+ '" target="_blank">' +taskreg+ '</a> </div> ' 

         html_report=html_report+' <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+taskdeign+ '">filename:'+taskdeign+ '</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+taskdeign+'" target="_blank">' +taskdeign+ '</a> </div> ' 


         #html_report=html_report + '<h1> task module </h1>  <p> Coregistration of T1w and Fucntional image <p> <object type="image/svg+xml" data="'+ taskreg + '" alt="Segmentation" width="2000"height="800"></object> \
           #<h3> Task design </h3> <p> Task design with 24 motion parameters </p> </h3>  <p> <p>   <object type="image/svg+xml" data="'+ taskdeign + '" alt="Segmentation" width="1200"height="420"></object>'
    elif i == 'qcfc' :
         os.system('cp '+ outdir+'/qcfc/'+prefix+'_voxts.png ' +outdir+'/figures/'+prefix+'_voxts.png')
         qcplot='figures/'+prefix+'_voxts.png'
         img1=load_img(outdir+'/prestats/'+prefix+'_preprocessed.nii.gz')
         img2=load_img(outdir+'/regress/'+prefix+'_residualised.nii.gz')
         seg=load_img(outdir+'/prestats/'+prefix+'_segmentation.nii.gz').get_fdata()
         tr=img2.header.get_zooms()[-1]
         #read confound and tr
         fd=np.loadtxt(outdir+'/confound2/mc/'+prefix+'_fd.1D')
         #dvar=np.loadtxt(outdir+'/confound2/mc/'+prefix+'_dvars-vox.1D')
         dvar2=np.loadtxt(outdir+'/qcfc/'+prefix+'_dvars-vox.1D')
         tmask=np.loadtxt(outdir+'/confound2/mc/'+prefix+'_tmask.1D')
     
         if tmask.size>1:
            fda=fd[tmask>0]  
         else:
            fda=fd
         checkfile =os.path.isfile(outdir+'/confound2/mc/'+prefix+'_dvars-vox.1D')
         if checkfile:
            fig = plt.figure(constrained_layout=False,figsize=(30,15))
            grid = mgs.GridSpec(3, 1, wspace=0.0, hspace=0.05,height_ratios=[1] * (3 - 1) + [5])
            dvar=np.loadtxt(outdir+'/confound2/mc/'+prefix+'_dvars-vox.1D')
            confoundplot(fd, grid[0], tr=tr, color='b',name='FD')
            confoundplot(dvar, grid[1], tr=tr, color='r',name='DVARS')
            plot_carpet(img1,seg, subplot=grid[-1],tr=tr)
            fig.savefig(outdir+'/figures/'+prefix+'_prestats.svg',bbox_inches="tight",pad_inches=None)
            prestatsfig='figures/'+prefix+'_prestats.svg'
         else:
            fig = plt.figure(constrained_layout=False,figsize=(30,15))
            grid = mgs.GridSpec(2, 1, wspace=0.0, hspace=0.05,height_ratios=[1] * (2 - 1) + [5])
            confoundplot(fd, grid[0], tr=tr, color='b',name='FD')
            plot_carpet(img1,seg, subplot=grid[-1],tr=tr)
            fig.savefig(outdir+'/figures/'+prefix+'_prestats.svg',bbox_inches="tight",pad_inches=None)
            prestatsfig='figures/'+prefix+'_prestats.svg'

         
         # after 
         #fig= plt.gcf()
         grid = mgs.GridSpec(3, 1, wspace=0.0, hspace=0.05,
                            height_ratios=[1] * (3 - 1) + [5])
         fig = plt.figure(constrained_layout=False,figsize=(30,15))
         confoundplot(fda, grid[0], tr=tr, color='b',name='FD')
         confoundplot(dvar2, grid[1], tr=tr, color='r',name='DVARS')
         plot_carpet(img2,seg, subplot=grid[-1],tr=tr)
         fig.savefig(outdir+'/figures/'+prefix+'_qcfc.svg',bbox_inches="tight",pad_inches=None)
         qcfcfig='figures/'+prefix+'_qcfc.svg'
          
         html_report=html_report+'<div id="qcfc"> </div>  </ul><h2 class="elem-title"> Assesment of  quality of functional connectivity data. \
                </h2><p class="elem-desc"> \
                  The first panel shows the spike plot consists of dvars (DV), relative motion (RMS) and framewise displacement (FD), \
                     The middle carpet plot is the raw BOLD data and bottom carpet plot is residualized BOLD data\
                     Check motionDVCorrInit (correlation of DV and RMS before regression) and motionDVCorrFinal (correlation of DV and RMS after regression) in the QC table above.<p><br />  \
                  <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+prestatsfig+ '">filename:'+prestatsfig+ '" alt="Segmentation" width="1000"height="800" </object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+prestatsfig+ '" target="_blank">' +prestatsfig+ '</a> </div> ' 

         html_report=html_report+' <div class="elem-image"> <object class="svg-reportlet" type="image/svg+xml" data="'+qcfcfig+ '">filename:'+qcfcfig+' " alt="Segmentation" width="1000"height="800"</object> \
                      </div> <div class="elem-filename"> Get figure file: <a href="'+qcfcfig+'" target="_blank">' +qcfcfig+ '</a> </div> ' 


         #html_report=html_report + '<h1> qcfc module </h1>  <h3> <p>  The spike plot consists of dvars (DV), relative motion (RMS) and framewise displacement (FD),  \
         #The middle carpet plot is the raw BOLD data and bottom carpet plot is residualized BOLD data </p>  <p> Check motionDVCorrInit (correlation of DV and RMS before regression) and motionDVCorrFinal \
         #(correlation of DV and RMS after regression) in the QC table above  </p> </h3>  <object type="image/svg+xml" data="'+ prestatsfig + '" alt="Segmentation" width="2000"height="1500"></object>'
         
         #html_report=html_report + '<h1> qcfc module </h1>  <p> <h3> FD, DVARS and BOLD Times series before regression </h3>  <p> <object type="image/svg+xml" data="'+ prestatsfig + '" alt="Segmentation" width="2000"height="1500"></object> \
          # <p> <h3>  DVARS and BOLD Times series after regression </h3>  </p> </h3> <p> <p> <object type="image/svg+xml" data="'+ qcfcfig+ '" alt="Segmentation" width="2000"height="1500"></object>'


    else :
        html_report=html_report + '</body>  </html>'

filereport=open(outdir+'/'+prefix+'_report.html','w')
filereport.write(html_report)
filereport.close()
