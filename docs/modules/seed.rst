.. _seed:

``seed``
=========

``seed`` performs seed-based correlation analyses given a seed region or set of seed regions. For
each seed region, which may be provided either as a 3D volume (mask) in NIfTI format or  coordinates.
``seed`` computes the pairwise connectivity between each voxel and the seed region,
for instance using the Pearson correlation coefficient between timeseries (Biswal et al., 1995).

``seed_points,seed_names and seed_radius``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``seed_names``  is three-letters to identify a seed for naming purpose and can be more than one.
  If this field is left blank, then no seed-based correlation analysis will be performed. The 
  ``seed_points`` are three coordnates (in mm)  of the seed point in template space. ``seed_points``
  and ``seed_names`` can be specify as shown below::  

  # for  one seed point correlation
  seed_names[cxt]=PCC # for seed at PCC
  seed_points[cxt]=0,-62,24 # seed location of PCC
  seed_radius[cxt]=8 # 8mm radius, 5mm will de used as if radius is not specify

  # for more than one seed loaction
  seed_names[cxt]=PCC#VMF#LOC   # PCC, VMF and LOC
  seed_points[cxt]=0,-62,24#0,34,-14#-36,-52,-2   # seed locations 
  
``seed_mask``
^^^^^^^^^^^^^^
A 3D mask can also be supply the mask must be derived from the template. xcpEngine assumes that 
the mask in the same dimesnion as template::
  seed_names[cxt]=PCC
  seed_mask[cxt]=/path/to/mask

``seed_sptf`` and ``seed_smo``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
*Spatial smoothing parameters.*

Endemic noise, for instance due to physiological signals or scanner activity, can introduce
spurious or artefactual results in single voxels. The effects of noise-related artefacts can be
mitigated by spatially filtering the data, thus dramatically increasing the signal-to-noise ratio.
However, spatial smoothing is not without its costs: it effectively reduces volumetric resolution
by blurring signals from adjacent voxels. The spatial smoothing implemented in the ``seed`` module
(i) keeps the unsmoothed analyte image for downstream use and (ii) creates a derivative image that
is smoothed using the specified kernel. This allows either the smoothed or the unsmoothed version
of the image to be used in any downstream modules as appropriate.::

  # No smoothing
  seed_sptf[cxt]=none
  seed_smo[cxt]=0

  # Gaussian kernel (fslmaths) of FWHM 6 mm
  seed_sptf[cxt]=gaussian
  seed_smo[cxt]=6

  # SUSAN kernel (FSL's SUSAN) of FWHM 4 mm
  seed_sptf[cxt]=susan
  seed_smo[cxt]=4

  # Uniform kernel (AFNI's 3dBlurToFWHM) of FWHM 5 mm
  seed_sptf[cxt]=uniform
  seed_smo[cxt]=5

``seed_sptf`` specifies the type of spatial filter to apply for smoothing, while ``seed_smo``
specifies the full-width at half-maximum (FWHM) of the smoothing kernel in mm.

 * Gaussian smoothing applies the same Gaussian smoothing kernel across the entire volume.
 * SUSAN-based smoothing restricts mixing of signals from disparate tissue classes (Smith and Brady, 1997).
 * Uniform smoothing applies smoothing to all voxels until the smoothness computed at every voxel attains the target value.
 * Uniform smoothing may be used as a compensatory mechanism to reduce the effects of subject motion on the final processed image (Scheinost et al., 2014).

``seed_rerun``
^^^^^^^^^^^^^^^^

Ordinarily, each module will detect whether a particular analysis has run to completion before
beginning it. If re-running is disabled, then the module will immediately skip to the next stage of
analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you
should rerun any modules downstream of the change.::

  # Skip processing steps if the pipeline detects the expected output
  seed_rerun[cxt]=0

  # Repeat all processing steps
  seed_rerun[cxt]=1

``seed_cleanup``
^^^^^^^^^^^^^^^^^^

Modules often produce numerous intermediate temporary files and images during the course of an
analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk
space. If cleanup is enabled, any files stamped as temporary will be deleted when a module
successfully runs to completion. If a module fails to detect the output that it expects, then
temporary files will be retained to facilitate error diagnosis.::

  # Remove temporary files
  seed_cleanup[cxt]=1

  # Retain temporary files
  seed_cleanup[cxt]=0

``Expected outputs``
^^^^^^^^^^^^^^^^^^^^^
  A sub-directory of ``seed_names`` is created in ``seed`` directory. The directory constist of::
    - prefix_connectivity_{seed_name}_seed.nii.gz # seed mask in BOLD space
    - prefix_connectivity_{seed_name}_sm*.nii.gz # seed correlation map 
    - prefix_connectivity_{seed_name}Z_sm*.nii.gz # Fisherz transfromed seed correlation map 
    - prefix_connectivity_{seed_name}_ts.1D  # time series of seed point