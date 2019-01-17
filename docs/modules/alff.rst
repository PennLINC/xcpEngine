.. _alff:

``alff``
=========

``alff`` computes the amplitude of low-frequency fluctuations (ALFF) in each voxel of the processed
image. Low-frequency fluctuations are of particular importance because functional connectivity is
most typically computed on the basis of synchronous activations at low frequencies. It is possible
that the magnitude (amplitude) of such activations has utility as a biomarker for pathologies or
psychological variables.

``alff_hipass`` and ``alff_lopass``
------------------------------------

The output of an ALFF analysis is dependent upon the precise definition of 'low frequency'. ALFF is
determined by computing a power spectrum at each voxel, then integrating over those frequencies of
the power spectrum that correspond to the user-specified passband. The low-pass cutoff frequency
corresponds to the upper limit of the passband; any frequencies lower than this cutoff are allowed
to pass. Similarly, the high-pass cutoff frequency corresponds to the upper limit of the passband;
any frequencies higher than this cutoff are allowed to pass. While the power-spectrum integral is
probably most informative when the limits of integration encompass low frequencies, advanced users
may elect to use this module to compute the amplitude of oscillations in any frequency range.::

  # Low-frequency pass-band 0.01-0.08 Hz
  alff_hipass[cxt]=0.01
  alff_lopass[cxt]=0.08

  # Low-frequency pass-band 0.008-0.12 Hz
  alff_hipass[cxt]=0.008
  alff_lopass[cxt]=0.12


``alff_sptf`` and ``alff_smo``

Spatial smoothing parameters.
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Endemic noise, for instance due to physiological signals or scanner activity, can introduce
spurious or artefactual results in single voxels. The effects of noise-related artefacts can be
mitigated by spatially filtering the data, thus dramatically increasing the signal-to-noise ratio.
However, spatial smoothing is not without its costs: it effectively reduces volumetric resolution
by blurring signals from adjacent voxels. The spatial smoothing implemented in the `alff` module
(i) keeps the unsmoothed analyte image for downstream use and (ii) creates a derivative image that
is smoothed using the specified kernel. This allows either the smoothed or the unsmoothed version
of the image to be used in any downstream modules as appropriate.::

  # No smoothing
  alff_sptf[cxt]=none
  alff_smo[cxt]=0

  # Gaussian kernel (fslmaths) of FWHM 6 mm
  alff_sptf[cxt]=gaussian
  alff_smo[cxt]=6

  # SUSAN kernel (FSL's SUSAN) of FWHM 4 mm
  alff_sptf[cxt]=susan
  alff_smo[cxt]=4

  # Uniform kernel (AFNI's 3dBlurToFWHM) of FWHM 5 mm
  alff_sptf[cxt]=uniform
  alff_smo[cxt]=5

``alff_sptf`` specifies the type of spatial filter to apply for smoothing, while ``alff_smo``
specifies the full-width at half-maximum (FWHM) of the smoothing kernel in mm.

 * Gaussian smoothing applies the same Gaussian smoothing kernel across the entire volume.
 * SUSAN-based smoothing restricts mixing of signals from disparate tissue classes (Smith and Brady, 1997).
 * Uniform smoothing applies smoothing to all voxels until the smoothness computed at every voxel attains the target value.
 * Uniform smoothing may be used as a compensatory mechanism to reduce the effects of subject motion on the final processed image (Scheinost et al., 2014).

``alff_rerun``
^^^^^^^^^^^^^^^

Ordinarily, each module will detect whether a particular analysis has run to completion before
beginning it. If re-running is disabled, then the module will immediately skip to the next stage of
analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you
should rerun any modules downstream of the change.::

  # Skip processing steps if the pipeline detects the expected output
  alff_rerun[cxt]=0

  # Repeat all processing steps
  alff_rerun[cxt]=1

``alff_cleanup``
^^^^^^^^^^^^^^^^^

Modules often produce numerous intermediate temporary files and images during the course of an
analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk
space. If cleanup is enabled, any files stamped as temporary will be deleted when a module
successfully runs to completion. If a module fails to detect the output that it expects, then
temporary files will be retained to facilitate error diagnosis.::

  # Remove temporary files
  alff_cleanup[cxt]=1

  # Retain temporary files
  alff_cleanup[cxt]=0
