
from nipype.pipeline import engine as pe
from nipype.interfaces import afni, ants, utility as niu
from nipype.interfaces.fsl import Split
from nipype.interfaces.fsl.preprocess import FUGUE,PRELUDE
import nibabel as nb 
import numpy as np 




def meanimage(in_file,out_file):
    'find mean of the 4D data'
    import nibabel as nb
    im=nb.load(in_file)
    data=im.get_data()
    if len(data.shape)==4: 
        data_mean=np.mean(data,axis=3)
    elif len(data.shape)==3:
        data_mean=data
    
    out_img = nb.Nifti1Image(data_mean,im.affine,im.header)
    out_img.to_filename(out_file)
    return out_img

def maskdata(in_file,out_file):
    'masking the data'
    im=nb.load(in_file)
    data=im.get_data()
    data=np.abs(data)
    data[data>0]=1
    out_img = nb.Nifti1Image(data_mean,im.affine,im.header)
    out_img.to_filename(out_file)
    return out_img


def n4_correction(in_infile):
    n4 = ants.N4BiasFieldCorrection()
    n4.inputs.dimension=3
    n4.inputs.input_image = im_input
    n4.inputs.bspline_fitting_distance = 300
    n4.inputs.shrink_factor = 3
    n4.inputs.n_iterations = [50, 50, 30, 20]
    n4.inputs.output_image = im_input.replace('.nii.gz', '_correcred.nii.gz')
    n4.run()
    return n4.output_image

def fslbet(in_file,out_file):
    bet=fsl.BET()
    out=bet.run(in_file=in_file,out_file=out_file,frac=0.5)
    return out_file


def antsregistration(fixed,moving,output_warped_image):
    reg = ants.Registration()in
    reg.inputs.fixed_image =fixed
    reg.inputs.moving_image =moving
    reg.inputs.output_transform_prefix = "output_"
    reg.inputs.transforms = ['SyN']
    reg.inputs.dimension = 3
    reg.inputs.output_warped_image = output_warped_image
    reg.inputs.collapse_output_transforms = True
    reg.run()
    return reg.inputs.output_warped_image, reg.outputs.composite_transform

def applytransform(in_file,reference,out_file,transformfile,interpolation='Linear'):
    at=ants.ApplyTransforms()
    at.inputs.dimension = 3
    at.inputs.input_image = in_file
    at.inputs.reference_image = reference
    at.inputs.output_image = out_file
    at.inputs.interpolation =interpolation
    at.inputs.transforms = transformfile 
    at.run()
    return at.inputs.output_image

def afnidQwarp():
    qwarp = afni.QwarpPlusMinus()
    qwarp.inputs.source_file = 'sub-01_dir-LR_epi.nii.gz'
    qwarp.inputs.nopadWARP = True
    qwarp.inputs.base_file = 'sub-01_dir-RL_epi.nii.gz'
    qwarp.run()  
    





    

        






def au2rads(in_file, newpath=None):
    """Convert the input phase difference map in arbitrary units (a.u.) to rads."""
    from scipy.stats import mode
    im = nb.load(in_file)
    data = im.get_fdata(dtype='float32')
    hdr = im.header.copy()

    # First center data around 0.0.
    data -= mode(data, axis=None)[0][0]

    # Scale lower tail
    data[data < 0] = - np.pi * data[data < 0] / data[data < 0].min()

    # Scale upper tail
    data[data > 0] = np.pi * data[data > 0] / data[data > 0].max()

    # Offset to 0 - 2pi
    data += np.pi

    # Clip
    data = np.clip(data, 0.0, 2 * np.pi)

    hdr.set_data_dtype(np.float32)
    hdr.set_xyzt_units('mm')
    out_file = fname_presuffix(in_file, suffix='_rads', newpath=newpath)
    nb.Nifti1Image(data, im.affine, hdr).to_filename(out_file)
    return out_file

def phdiff2fmap(in_file, delta_te, newpath=None):
    r"""
    Convert the input phase-difference map into a fieldmap in Hz.
    Uses eq. (1) of [Hutton2002]_:
    .. math::
        \Delta B_0 (\text{T}^{-1}) = \frac{\Delta \Theta}{2\pi\gamma \Delta\text{TE}}
    In this case, we do not take into account the gyromagnetic ratio of the
    proton (:math:`\gamma`), since it will be applied inside TOPUP:
    .. math::
        \Delta B_0 (\text{Hz}) = \frac{\Delta \Theta}{2\pi \Delta\text{TE}}
    References
    ----------
    .. [Hutton2002] Hutton et al., Image Distortion Correction in fMRI: A Quantitative
      Evaluation, NeuroImage 16(1):217-240, 2002. doi:`10.1006/nimg.2001.1054
      <https://doi.org/10.1006/nimg.2001.1054>`_.
    """
    import math
    import numpy as np
    import nibabel as nb
    from nipype.utils.filemanip import fname_presuffix
    #  GYROMAG_RATIO_H_PROTON_MHZ = 42.576

    out_file = fname_presuffix(in_file, suffix='_fmap', newpath=newpath)
    image = nb.load(in_file)
    data = (image.get_fdata(dtype='float32') / (2. * math.pi * delta_te))
    nii = nb.Nifti1Image(data, image.affine, image.header)
    nii.set_data_dtype(np.float32)
    nii.to_filename(out_file)
    return out_file

    def _torads(in_file, fmap_range=None, newpath=None):
    """
    Convert a field map to rad/s units.
    If fmap_range is None, the range of the fieldmap
    will be automatically calculated.
    Use fmap_range=0.5 to convert from Hz to rad/s
    """
    from math import pi
    import nibabel as nb
    from nipype.utils.filemanip import fname_presuffix

    out_file = fname_presuffix(in_file, suffix='_rad', newpath=newpath)
    fmapnii = nb.load(in_file)
    fmapdata = fmapnii.get_fdata(dtype='float32')

    if fmap_range is None:
        fmap_range = max(abs(fmapdata.min()), fmapdata.max())
    fmapdata = fmapdata * (pi / fmap_range)
    out_img = nb.Nifti1Image(fmapdata, fmapnii.affine, fmapnii.header)
    out_img.set_data_dtype('float32')
    out_img.to_filename(out_file)
    return out_file, fmap_range


def _tohz(in_file, range_hz, newpath=None):
    """Convert a field map to Hz units."""
    from math import pi
    import nibabel as nb
    from nipype.utils.filemanip import fname_presuffix

    out_file = fname_presuffix(in_file, suffix='_hz', newpath=newpath)
    fmapnii = nb.load(in_file)
    fmapdata = fmapnii.get_fdata(dtype='float32')
    fmapdata = fmapdata * (range_hz / pi)
    out_img = nb.Nifti1Image(fmapdata, fmapnii.affine, fmapnii.header)
    out_img.set_data_dtype('float32')
    out_img.to_filename(out_file)
    return out_file

def _despike2d(data, thres, neigh=None):
    """Despike axial slices, as done in FSL's ``epiunwarp``."""
    if neigh is None:
        neigh = [-1, 0, 1]
    nslices = data.shape[-1]

    for k in range(nslices):
        data2d = data[..., k]

        for i in range(data2d.shape[0]):
            for j in range(data2d.shape[1]):
                vals = []
                thisval = data2d[i, j]
                for ii in neigh:
                    for jj in neigh:
                        try:
                            vals.append(data2d[i + ii, j + jj])
                        except IndexError:
                            pass
                vals = np.array(vals)
                patch_range = vals.max() - vals.min()
                patch_med = np.median(vals)

                if (patch_range > 1e-6 and
                        (abs(thisval - patch_med) / patch_range) > thres):
                    data[i, j, k] = patch_med
    return data








    def _unwrap(fmap_data, mag_file, mask=None):
    from math import pi
    from nipype.interfaces.fsl import PRELUDE
    magnii = nb.load(mag_file)

    if mask is None:
        mask = np.ones_like(fmap_data, dtype=np.uint8)

    fmapmax = max(abs(fmap_data[mask > 0].min()), fmap_data[mask > 0].max())
    fmap_data *= pi / fmapmax

    nb.Nifti1Image(fmap_data, magnii.affine).to_filename('fmap_rad.nii.gz')
    nb.Nifti1Image(mask, magnii.affine).to_filename('fmap_mask.nii.gz')
    nb.Nifti1Image(magnii.get_fdata(dtype='float32'),
                   magnii.affine).to_filename('fmap_mag.nii.gz')

    # Run prelude
    res = PRELUDE(phase_file='fmap_rad.nii.gz',
                  magnitude_file='fmap_mag.nii.gz',
                  mask_file='fmap_mask.nii.gz').run()

    unwrapped = nb.load(
        res.outputs.unwrapped_phase_file).get_fdata(dtype='float32') * (fmapmax / pi)
    return unwrapped