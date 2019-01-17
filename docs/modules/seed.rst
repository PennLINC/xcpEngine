.. _seed:

``seed``
=========

``seed`` performs seed-based correlation analyses given a seed region or set of seed regions. For
each seed region, which may be provided either as a 3D volume in NIfTI format or as coordinates in
a library file, ``seed`` computes the pairwise connectivity between each voxel and the seed region,
for instance using the Pearson correlation coefficient between timeseries (Biswal et al., 1995).

``seed_lib``
^^^^^^^^^^^^^^^^^^

*Spatial coordinates library.*

The spatial coordinates library (``.sclib``) is a file containing an index of the seed regions for
which the correlation analysis should be run. Each seed is represented by a line in the ``sclib``
file that begins with the ``#`` (hash/octothorpe) character. Seeds can be denoted using spatial
coordinates or using volumetric NIfTI images. If this field is left blank, then no seed-based
correlation analysis will be performed.::

  # Use posterior_cingulate.sclib
  seed_lib[cxt]=posterior_cingulate.sclib

  # Skip seed-based correlation analysis
  seed_lib[cxt]=

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
