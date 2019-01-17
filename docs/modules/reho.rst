.. _reho:

``reho``
=========

``reho`` computes the regional homogeneity (ReHo) at each voxel of the processed image and/or within
user-specified *a priori* regions of interest. ReHo, or Kendall's W, is a measure of local
uniformity in the BOLD signal. Greater ReHo values correspond to greater synchrony among BOLD
activation patterns measured in a neighbourhood of voxels.

``reho_nhood``
^^^^^^^^^^^^^^^
*Voxel neighbourhood.*

Regional homogeneity is computed as Kendall's W (coefficient of concordance) among the timeseries
of a voxel and its neighbours. The neighbours of a voxel may include either:

 * ``faces``: Any of the 6 voxels adjoining that voxel along the surfaces of its faces
 * ``edges``: Any of the 18 voxels adjoining that voxel along its faces or edges
 * ``vertices``: Any of the 26 voxels adjoining that voxel at any of its faces, edges, or vertices
 * ``sphere``: Any voxels that lie within a sphere of user-specified radius from that voxel.

Regional homogeneity may be computed for each voxel in such a manner as to consider any voxels
within a user-specified radius of that voxel to be that voxel's neighbourhood. The regional
homogeneity will then be defined as the coefficient of concordance among all voxels in a sphere
centred on the target voxel. The neighbourhood radius should be provided in millimeters.::

  # 7-voxel neighbourhood incident on faces
  reho_nhood[cxt]=faces

  # 19-voxel neighbourhood incident on faces or edges
  reho_nhood[cxt]=edges

  # 27-voxel neighbourhood incident on faces, edges, or vertices
  reho_nhood[cxt]=vertices

  # spherical neighbourhood of radius 12 mm
  reho_nhood[cxt]=sphere,12

``reho_sptf`` and ``reho_smo``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

*Spatial smoothing parameters.*

Endemic noise, for instance due to physiological signals or scanner activity, can introduce
spurious or artefactual results in single voxels. The effects of noise-related artefacts can be
mitigated by spatially filtering the data, thus dramatically increasing the signal-to-noise ratio.
However, spatial smoothing is not without its costs: it effectively reduces volumetric resolution
by blurring signals from adjacent voxels. Regional homogeneity will be artificially inflated if the
analysis is performed on a smoothed image because smoothing enforces a degree of autocorrelation or
synchrony among spatially proximal voxels. Thus, the ``reho`` module *always* performs analysis on
an unsmoothed image. The spatial smoothing implemented in the ``reho`` module is performed after
the regional homogeneity map is computed voxelwise; the voxelwise map is smoothed.::

  # No smoothing
  reho_sptf[cxt]=none
  reho_smo[cxt]=0

  # Gaussian kernel (fslmaths) of FWHM 6 mm
  reho_sptf[cxt]=gaussian
  reho_smo[cxt]=6

  # SUSAN kernel (FSL's SUSAN) of FWHM 4 mm
  reho_sptf[cxt]=susan
  reho_smo[cxt]=4

  # Uniform kernel (AFNI's 3dBlurToFWHM) of FWHM 5 mm
  reho_sptf[cxt]=uniform
  reho_smo[cxt]=5

``reho_sptf`` specifies the type of spatial filter to apply for smoothing, while ``reho_smo``
specifies the full-width at half-maximum (FWHM) of the smoothing kernel in mm.

 * Gaussian smoothing applies the same Gaussian smoothing kernel across the entire volume.
 * SUSAN-based smoothing restricts mixing of signals from disparate tissue classes
   (Smith and Brady, 1997).
 * Uniform smoothing applies smoothing to all voxels until the smoothness computed at every voxel
   attains the target value.
 * Uniform smoothing may be used as a compensatory mechanism to reduce the effects of subject
   motion on the final processed image (Scheinost et al., 2014).

``reho_rerun``
^^^^^^^^^^^^^^^^

Ordinarily, each module will detect whether a particular analysis has run to completion before
beginning it. If re-running is disabled, then the module will immediately skip to the next stage of
analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you
should rerun any modules downstream of the change.::

  # Skip processing steps if the pipeline detects the expected output
  reho_rerun[cxt]=0

  # Repeat all processing steps
  reho_rerun[cxt]=1

``reho_cleanup``
^^^^^^^^^^^^^^^^^^

Modules often produce numerous intermediate temporary files and images during the course of an
analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk
space. If cleanup is enabled, any files stamped as temporary will be deleted when a module
successfully runs to completion. If a module fails to detect the output that it expects, then
temporary files will be retained to facilitate error diagnosis.::

  # Remove temporary files
  reho_cleanup[cxt]=1

  # Retain temporary files
  reho_cleanup[cxt]=0
