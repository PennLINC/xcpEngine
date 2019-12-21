.. _seedconnectivity:


Seed-based connectivity 
========================

Seed-based connectivity provides the opportunity to compute the  functional connectivity between 
the a point/region and  all other voxels in the brain. The users can specify a 3 coordinates point 
in mm of a template or a mask with the same dimension and orietation of a template. If no template is 
provided,  ``MNI152_T1_2mm_brain.nii.gz`` will be used as default template. 

The seed connectivity is done with ${XCPEDIR}/utils/seedconnectivity::


    ${XCPEDIR}/utils/seedconnectivity   \
    -i  input4Dimage  \     #  4D inputimage usually residualised or image or filtered image
    -s  x,y,z   \           # 3 cordinates  or a mask (--s=/path/to/mask)
    -o  outputpath  \       # output directory 
    -r  radius \            # radius of the mask for 3 points cordinates, r=5 is default
    -k  kernel \            # kernel size if the image is not filtered
    -t  template  \         # template; MNI152_T1_2mm_brain.nii.gz is default
    -n  seed_name \         # SEED will used as default
    -p  subject identifiers

The first three opions (-img,--sand -o ) are mandatory.
If the input image is residualised BOLD image (regress/sub-*residualized.nii.gz) from `regress` 
module which is not spatially smooth, theuser is encourage to smooth the image. Kernel of 5mm 
FHWM is preffered for good connectivity results.

Expected outputs
A sub-directory of seed_names is created in seed directory. The directory constist of::
      -prefix_connectivity_{seed_name}_seed.nii.gz # seed mask in BOLD space
      -prefix_connectivity_{seed_name}_smK.nii.gz # seed correlation map, K is kernel size
      -prefix_connectivity_{seed_name}Z_smK.nii.gz # Fisherz transfromed seed correlation map
      -prefix_connectivity_{seed_name}_ts.1D # time series of seed point/mask

