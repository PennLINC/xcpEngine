import numpy as np
import nibabel as nb
import pandas as pd
import sys 

from nibabel.cifti2 import Cifti2Image
from sklearn.linear_model import LinearRegression
from scipy.signal import butter, filtfilt
from nilearn.signal import clean 

import matplotlib.pyplot as plt
from matplotlib import gridspec as mgs
import matplotlib.cm as cm
from matplotlib.colors import ListedColormap, Normalize
import seaborn as sns
from seaborn import color_palette




def surface_filt_reg(datafile,confound,lowpass,highpass,outfilename,pre_svg,post_svg,fd,tr,
                     dvars,process_order=['DMT','REG','TMP'],filter_order=2):
    '''
    input file 
    datafile : gifti or cifti file
    tr : repetition time 
    confound: confound matrix in regressors by timepoints
    lowpass: lowpas filter in Hz
    highpass: highpass filter in Hz
    outfilename: outputput file name
    pre_svg: plot of svg name before regression
    post_svg: plot of svg name after regression 
    fd: framewise displacement
    dvars: dvars before regression
    
    '''
    
    datamatrix=read_gifti_cifti(datafile=datafile)
    dd_data=demean_detrend_data(data=datamatrix,TR=tr,order=1)
    dd_confound=demean_detrend_data(data=confound,TR=tr,order=1)
    if process_order[1] == 'TMP':
        filtered_data = butter_bandpass(data=dd_data,fs=1/tr,lowpass=lowpass,highpass=highpass,order=2)
        filtered_confound = butter_bandpass(data=dd_confound,fs=1/tr,lowpass=lowpass,highpass=highpass,order=2)
        pre_davrs=compute_dvars(datat = datamatrix)
        reg_data = linear_regression(data=filtered_data,confound=filtered_confound)
        plot_svg(fdata=datamatrix,fd=fd,dvars=pre_davrs,filename=pre_svg,tr=tr)
        reg_davrs=compute_dvars(datat = reg_data)
        plot_svg(fdata=reg_data,fd=fd,dvars=reg_davrs,filename=post_svg,tr=tr)
        write_gifti_cifti(data_matrix=reg_data,template=datafile,filename=outfilename)
    elif process_order[1] == 'REG':
        reg_data = linear_regression(data=dd_data,confound=dd_confound)
        pre_davrs=compute_dvars(datat = datamatrix)
        filtered_data = butter_bandpass(data=reg_data,fs=1/tr,lowpass=lowpass,highpass=highpass,order=2)
        plot_svg(fdata=pre_davrs,fd=fd,dvars=pre_davrs,filename=pre_svg,tr=tr)
        reg_davrs=compute_dvars(datat = filtered_data)
        plot_svg(fdata=filtered_data,fd=fd,dvars=reg_davrs,filename=post_svg,tr=tr)
        write_gifti_cifti(data_matrix=filtered_data,template=datafile,filename=outfilename)
        
    return outfilename 


def demean_detrend_data(data,TR,order=1):
    '''
    data should be voxels/vertices by timepoints dimension
    order=1
    # order of polynomial detrend is usually obtained from 
    # order = floor(1 + TR*nVOLS / 150)
    TR= repetition time
    this can be use for both timeseries and bold 
    '''
    
    # demean the data first, check if it has been demean
    if np.mean(data) > 0.00000000001:
        mean_data=np.mean(data,axis=1)
        means_expanded = np.outer(mean_data, np.ones(data.shape[1]))
        demeand=data-means_expanded
    else:
        demeand=data
    x=np.linspace(0,(data.shape[1]-1)*TR,num=data.shape[1])
    predicted=np.zeros_like(demeand)
    for j in range(demeand.shape[0]):
        model = np.polyfit(x,demeand[j,:],order)
        predicted[j,:] = np.polyval(model, x) 
    return demeand - predicted

from scipy.signal import butter, filtfilt

def butter_bandpass(data,fs,lowpass,highpass,order=2):
    '''
    data : voxels/vertices by timepoints dimension
    fs : sampling frequency, =1/TR(s)
    lowpass frequency
    highpass frequency 
    '''
    
    nyq = 0.5 * fs
    lowcut = np.float(highpass) / nyq
    highcut = np.float(lowpass) / nyq
    b, a = butter(order, [lowcut, highcut], btype='band')
    mean_data=np.mean(data,axis=1)
    y=np.zeros_like(data)
    for i in range(data.shape[0]):
        y[i,:] = filtfilt(b, a, data[i,:])
    #add mean back 
    mean_datag=np.outer(mean_data, np.ones(data.shape[1]))
    return y 

def linear_regression(data,confound):
    
    '''
     both data and confound should be point/voxels/vertices by timepoints
    '''
    regr = LinearRegression()
    regr.fit(confound.T,data.T)
    y_pred = regr.predict(confound.T)
    return data - y_pred.T

def read_gifti_cifti(datafile):
    if datafile.endswith('.dtseries.nii'):
        data=nb.load(datafile).get_fdata().T
    elif datafile.endswith('.func.gii'):
        data=nb.load(datafile).agg_data()
    return data
    
    
def write_gifti_cifti(data_matrix,template,filename):
    '''
    data matrix:  veritices by timepoint 
    template: real file loaded with nibabel to get header and filemap
    filename ; name of the output
    '''
    if template.endswith('.dtseries.nii'):
        from nibabel.cifti2 import Cifti2Image
        template=nb.load(template)
        dataimg=Cifti2Image(dataobj=data_matrix.T,header=template.header,
                    file_map=template.file_map,nifti_header=template.nifti_header)
        
    elif template.endswith('.func.gii'):
        template=nb.load(template)
        dataimg=nb.gifti.GiftiImage(header=template.header,file_map=template.file_map,extra=template.extra)
        for i in range(data_matrix.shape[1]):
            d_timepoint=nb.gifti.GiftiDataArray(data=np.asarray(data_matrix[:,i]),intent='NIFTI_INTENT_TIME_SERIES')
            dataimg.add_gifti_data_array(d_timepoint)
    dataimg.to_filename(filename)
    return filename

def compute_dvars(datat):
    '''
     datat should be points by timepoints
    '''
    firstcolumn=np.zeros((datat.shape[0]))[...,None]
    datax=np.hstack((firstcolumn,np.diff(datat)))
    datax_ss=np.sum(np.square(datax),axis=0)/datat.shape[0]
    return np.sqrt(datax_ss)

def plot_carpet(func_data,detrend=True, nskip=0, size=(950, 800),
                subplot=None, title=None, output_file=None, legend=False,
                tr=None):
    """
    Plot an image representation of voxel intensities across time also know
    as the "carpet plot" or "Power plot". See Jonathan Power Neuroimage
    2017 Jul 1; 154:150-158.
    Parameters
    ----------
        img : Niimg-like object
            See http://nilearn.github.io/manipulating_images/input_output.html
            4D input image
        atlaslabels: ndarray
            A 3D array of integer labels from an atlas, resampled into ``img`` space.
        detrend : boolean, optional
            Detrend and standardize the data prior to plotting.
        nskip : int
            Number of volumes at the beginning of the scan marked as nonsteady state.
        long_cutoff : int
            Number of TRs to consider img too long (and decimate the time direction
            to save memory)
        axes : matplotlib axes, optional
            The axes used to display the plot. If None, the complete
            figure is used.
        title : string, optional
            The title displayed on the figure.
        output_file : string, or None, optional
            The name of an image file to export the plot to. Valid extensions
            are .png, .pdf, .svg. If output_file is not None, the plot
            is saved to a file, and the display is closed.
        legend : bool
            Whether to render the average functional series with ``atlaslabels`` as
            overlay.
        tr : float , optional
            Specify the TR, if specified it uses this value. If left as None,
            # Frames is plotted instead of time.
    """

    # Define TR and number of frames
    notr = False
    if tr is None:
        notr = True
        tr = 1.

    
    ntsteps = func_data.shape[-1]

    data = func_data.reshape(-1, ntsteps)


    p_dec = 1 + data.shape[0] // size[0]
    if p_dec:
        data = data[::p_dec, :]

    t_dec = 1 + data.shape[1] // size[1]
    if t_dec:
        data = data[:, ::t_dec]

    # Detrend data
    v = (None, None)
    if detrend:
        data = clean(data.T, t_r=tr).T
        v = (-2, 2)
    # If subplot is not defined
    if subplot is None:
        subplot = mgs.GridSpec(1, 1)[0]

    # Define nested GridSpec
    wratios = [1, 100, 20]
    gs = mgs.GridSpecFromSubplotSpec(1, 2 + int(legend), subplot_spec=subplot,
                                     width_ratios=wratios[:2 + int(legend)],
                                     wspace=0.0)

    mycolors = ListedColormap(cm.get_cmap('Set1').colors[:3][::-1])


    # Carpet plot
    ax1 = plt.subplot(gs[1])
    ax1.imshow(data, interpolation='nearest', aspect='auto', cmap='gray',
               vmin=v[0], vmax=v[1])
    ax1.grid(False)
    ax1.set_yticks([])
    ax1.set_yticklabels([])

    # Set 10 frame markers in X axis
    interval = max((int(data.shape[-1] + 1) //
                    10, int(data.shape[-1] + 1) // 5, 1))
    xticks = list(range(0, data.shape[-1])[::interval])
    ax1.set_xticks(xticks)
    if notr:
        ax1.set_xlabel('time (frame #)')
    else:
        ax1.set_xlabel('time (s)')
    labels = tr * (np.array(xticks)) * t_dec
    ax1.set_xticklabels(['%.02f' % t for t in labels.tolist()], fontsize=10)

    # Remove and redefine spines
    for side in ["top", "right"]:
        ax1.spines[side].set_color('none')
        ax1.spines[side].set_visible(False)

    ax1.yaxis.set_ticks_position('left')
    ax1.xaxis.set_ticks_position('bottom')
    ax1.spines["bottom"].set_visible(False)
    ax1.spines["left"].set_color('none')
    ax1.spines["left"].set_visible(False)
    if output_file is not None:
        figure = plt.gcf()
        figure.savefig(output_file, bbox_inches='tight')
        plt.close(figure)
        figure = None
        return output_file

    return [ax1], gs

def confoundplot(tseries, gs_ts, gs_dist=None, name=None,
                 units=None, tr=None, hide_x=True, color='b', nskip=0,
                 cutoff=None, ylims=None):

    # Define TR and number of frames
    notr = False
    if tr is None:
        notr = True
        tr = 1.
    ntsteps = len(tseries)
    tseries = np.array(tseries)

    # Define nested GridSpec
    gs = mgs.GridSpecFromSubplotSpec(1, 2, subplot_spec=gs_ts,
                                     width_ratios=[1, 100], wspace=0.0)

    ax_ts = plt.subplot(gs[1])
    ax_ts.grid(False)

    # Set 10 frame markers in X axis
    interval = max((ntsteps // 10, ntsteps // 5, 1))
    xticks = list(range(0, ntsteps)[::interval])
    ax_ts.set_xticks(xticks)

    if not hide_x:
        if notr:
            ax_ts.set_xlabel('time (frame #)')
        else:
            ax_ts.set_xlabel('time (s)')
            labels = tr * np.array(xticks)
            ax_ts.set_xticklabels(['%.02f' % t for t in labels.tolist()])
    else:
        ax_ts.set_xticklabels([])

    if name is not None:
        if units is not None:
            name += ' [%s]' % units

        ax_ts.annotate(
            name, xy=(0.0, 0.7), xytext=(0, 0), xycoords='axes fraction',
            textcoords='offset points', va='center', ha='left',
            color=color, size=20,
            bbox={'boxstyle': 'round', 'fc': 'w', 'ec': 'none',
                  'color': 'none', 'lw': 0, 'alpha': 0.8})

    for side in ["top", "right"]:
        ax_ts.spines[side].set_color('none')
        ax_ts.spines[side].set_visible(False)

    if not hide_x:
        ax_ts.spines["bottom"].set_position(('outward', 20))
        ax_ts.xaxis.set_ticks_position('bottom')
    else:
        ax_ts.spines["bottom"].set_color('none')
        ax_ts.spines["bottom"].set_visible(False)

    # ax_ts.spines["left"].set_position(('outward', 30))
    ax_ts.spines["left"].set_color('none')
    ax_ts.spines["left"].set_visible(False)
    # ax_ts.yaxis.set_ticks_position('left')

    ax_ts.set_yticks([])
    ax_ts.set_yticklabels([])

    nonnan = tseries[~np.isnan(tseries)]
    if nonnan.size > 0:
        # Calculate Y limits
        valrange = (nonnan.max() - nonnan.min())
        def_ylims = [nonnan.min() - 0.1 * valrange,
                     nonnan.max() + 0.1 * valrange]
        if ylims is not None:
            if ylims[0] is not None:
                def_ylims[0] = min([def_ylims[0], ylims[0]])
            if ylims[1] is not None:
                def_ylims[1] = max([def_ylims[1], ylims[1]])

        # Add space for plot title and mean/SD annotation
        def_ylims[0] -= 0.1 * (def_ylims[1] - def_ylims[0])

        ax_ts.set_ylim(def_ylims)

        # Annotate stats
        maxv = nonnan.max()
        mean = nonnan.mean()
        stdv = nonnan.std()
        p95 = np.percentile(nonnan, 95.0)
    else:
        maxv = 0
        mean = 0
        stdv = 0
        p95 = 0

    stats_label = (r'max: {max:.3f}{units} $\bullet$ mean: {mean:.3f}{units} '
                   r'$\bullet$ $\sigma$: {sigma:.3f}').format(
        max=maxv, mean=mean, units=units or '', sigma=stdv)
    ax_ts.annotate(
        stats_label, xy=(0.98, 0.7), xycoords='axes fraction',
        xytext=(0, 0), textcoords='offset points',
        va='center', ha='right', color=color, size=10,
        bbox={'boxstyle': 'round', 'fc': 'w', 'ec': 'none', 'color': 'none',
              'lw': 0, 'alpha': 0.8}
    )

    # Annotate percentile 95
    ax_ts.plot((0, ntsteps - 1), [p95] * 2, linewidth=.1, color='lightgray')
    ax_ts.annotate(
        '%.2f' % p95, xy=(0, p95), xytext=(-1, 0),
        textcoords='offset points', va='center', ha='right',
        color='lightgray', size=3)

    if cutoff is None:
        cutoff = []

    for i, thr in enumerate(cutoff):
        ax_ts.plot((0, ntsteps - 1), [thr] * 2,
                   linewidth=.2, color='dimgray')

        ax_ts.annotate(
            '%.2f' % thr, xy=(0, thr), xytext=(-1, 0),
            textcoords='offset points', va='center', ha='right',
            color='dimgray', size=3)

    ax_ts.plot(tseries, color=color, linewidth=1.5)
    ax_ts.set_xlim((0, ntsteps - 1))

    if gs_dist is not None:
        ax_dist = plt.subplot(gs_dist)
        sns.displot(tseries, vertical=True, ax=ax_dist)
        ax_dist.set_xlabel('Timesteps')
        ax_dist.set_ylim(ax_ts.get_ylim())
        ax_dist.set_yticklabels([])

        return [ax_ts, ax_dist], gs
    return ax_ts, gs

def plot_svg(fdata,fd,dvars,filename,tr=1):
    '''
    plot carpetplot with fd and dvars
    '''
    fig = plt.figure(constrained_layout=False, figsize=(30, 15))
    grid = mgs.GridSpec(3, 1, wspace=0.0, hspace=0.05,
                               height_ratios=[1] * (3 - 1) + [5])
    confoundplot(fd, grid[0], tr=tr, color='b', name='FD')
    confoundplot(dvars, grid[1], tr=tr, color='r', name='DVARS')
    plot_carpet(func_data=fdata,subplot=grid[-1], tr=tr,)
    fig.savefig(filename,bbox_inches="tight", pad_inches=None)
