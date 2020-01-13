
from fmapprocessing import phdiff2fmap,au2rads, maskdata,n4_correction, fslbet
from fmapprocessing import _despike2d, _unwrap, substractimage,substractphaseimage
from nipype.interfaces.process import fsl

#convert phasm to rads
phase1='pahse1.nii.gz'
phase2='pahse2.nii.gz'
phi1='phase1torads'
phi2='phase2torads'
ph1=au2rads(phase1,phi1)
ph2=au2rads(phase2,phi2)

# Substract phase1 and phase 2
phasediff='phasediff'
phdiff=substractphaseimage(phi1,phi2,phasediff)
# process magnitude, n4, bet, 
mag='mag1.nii.gz'
mag_bias=n4_correction(in_file=mag)
mag_brain'mag1_brain.nii.gz'
mag_mask='mag1_mask.nii.gz'
mag_brain=fslbet(in_file=mag_bias,out_file=mag_brain)
mag_mask=maskdata(mag_brain,mag_mask)

#unwarp withe predule 
unwrapped='unwrapped.nii.gz'
prefsl=fsl.predule()
prefsl.magnitude_file=mag_brain
prefsl.phase_file=phdiff
prefsl.mask_file=mag_mask
prefsl.unwrapped_phase_file=unwrapped
prefsl.run()
#denoise demean recenter the fieldmap and 
# denoise with fsl spatial filter 
denoise=fsl.SpatialFilter()
denoise.inputs.kernel_shape='sphere'
denoise.inputs.kernel_size=3
denoise.inputs.operation='median'
denoise.inputs.out_file='unwrapped_denoise.nii.gz'
denoise.cmdline
denoise.run()






# convert to fieldmap