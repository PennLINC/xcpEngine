.. _confound:

``confound2``
======================================

``confound2`` models artefactual signals present in a 4D time series image. The confound model
created by this module can be used to mitigate effects of subject motion and other artefactual
processes by residualising the 4D image with respect to the confound model. (The
regression/residualisation procedure is managed separately in the ``regress`` module.) Several
types of artefact can be modelled: physiological sources, including white matter and CSF signals;
global signal; realignment parameters; and signals derived from principal component analysis (PCA,
CompCor). Derivatives and squares can also be added to the confound model, as can signal during
prior time points.  

If you wish to include confounds based on segmentation of T1-weighted tissue (including WM- and
CSF-based signals), you must run ``coreg`` first.

Model construction order
----------------------------

Currently, the confound model is assembled in the following order:

  1. Add realignment parameters and mean time series from GM, WM, CSF, and global
  2. Add temporal derivatives of any time series in the model
  3. Add powers of any time series in the model (e.g., quadratic terms)
  4. Add component-based time series (CompCor)
  5. Add custom time series

So, for instance, including the second power will also include not only the squared time series,
but also the squares of derivatives.

In the future, a control sequence will probably be implemented to support greater flexibility in
confound models.

Module configuration
----------------------

``confound_rp``
^^^^^^^^^^^^^^^^^

*Realignment parameters.*

Early models that attempted to correct for the introduction of spurious variance by the movement of
subjects in the scanner did so by regressing out the 6 parameters (3 translational, 3 rotational)
used to realign each volume in the time series to a reference volume. Later work has demonstrated
that a model consisting of realignment parameters alone is ineffective at removing motion artefact
from functional MR time series.::

  # Use realignment parameters
  confound_rp[cxt]=1

  # No realignment parameters
  confound_rp[cxt]=0

``confound_rms``
^^^^^^^^^^^^^^^^^

*Relative RMS displacement*

The relative root-mean-square displacement is estimated by FSL's MCFLIRT. This is equivalent to the
Jenkinson formulation of framewise displacement and is approximately double the Power formulation
of framewise displacement. Using the relative RMS displacement as a confound time series is not
recommended; this is an uncommon denoising strategy and is not likely to be effective.::

  # Use RMS displacement
  confound_rms[cxt]=1

  # No RMS displacement
  confound_rms[cxt]=0

``confound_gm``, ``confound_wm``, and ``confound_csf``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

*Tissue-based nuisance regressors, including aCompCor.*

Tissue-based nuisance regressors are capable of reducing the influence of subject movement (as well
as physiological artefacts) on the data. Mean white matter and cerebrospinal fluid signal are most
often used to this end (e.g., Windischberger et al., 2002; Satterthwaite et al., 2012), but
principal component analysis can also be used to extract signals of no interest from anatomical
compartments (Behzadi et al., 2007: aCompCor).  The number of aCompCor components removed can either 
be specified as a fixed number, or by the percent variance explained (usually this is 50%  as in
Muschelli et al., 2014.)  This approach requires a known segmentation of the
anatomical image into tissue classes. If you provided an output directory from the ANTsCT routine
or the anatomical stream, then a segmentation will automatically be available as the derivative
``segmentation``. 

  # Do not use any white matter signals
  confound_wm[cxt]=0

  # Use the mean white matter signal
  confound_wm[cxt]=1

  # Use the first 5 principal components from white matter (aCompCor)
  confound_wm[cxt]=5

  # Use the first n principal components, where n components are sufficient to explain 50 percent of variance in the white matter
  confound_wm[cxt]=0.5

Interpreting

 * ``mean`` indicates that the mean time series over all voxels inside the tissue boundaries
   should be used in the confound model.
 * A positive numeric value indicates that principal component analysis (PCA) over all voxels
   inside the tissue boundaries should be used to obtain nuisance time series.
 * If the value is an integer *n*, then the first *n* component time series will be added to the
   nuisance model.
 * If the value is a fractional value *k* between 0 and 1, then the first *n* component time
   series will be added to the nuisance model, where *n* is the minimum number of components
   necessary to explain *k* of the variance in the signal within the component boundaries. For
   instance, *k* of ``0.5`` corresponds to 50 percent variance explained.

Use of tissue-based nuisance regressors requires a known segmentation of the anatomical image into
tissue classes. If you provided an output directory from the ANTsCT routine or the anatomical
stream, then a segmentation will automatically be available as the derivative ``segmentation``. In
some segmentations, such as the one output by ANTs Cortical Thickness, each tissue class is
assigned a different intensity value in the segmentation volume. For instance, 1 might correspond
to CSF, 2 to cortical grey matter, 3 to white matter, etc. If your segmentation is strictly a
binary-valued white matter mask, then enter ``ALL``. To enter a range of values, use the colon
(``:``) delimiter; to enter multiple values, use the comma (``,``) delimiter.::

  # Use a custom segmentation for WM
  confound_wm_path[cxt]=/path/to/segmentation.nii.gz

  # Use the segmentation from ANTsCT or the anatomical stream for WM
  confound_wm_path=${segmentation[sub]}

  # Use the mean CSF signal. Use the pipeline segmentation for CSF. 1=CSF in the provided CSF segmentation path.
  confound_csf[cxt]=1
  confound_csf_path[cxt]=${segmentation[sub]}
  confound_csf_val[cxt]=1

In order to ensure that the signal extracted from the tissue or region of interest is not mixed
with signal from adjacent voxels associated with a different tissue class (partial volume effects),
it is possible to erode its mask by removing fringe voxels. An optimal degree of erosion will
result in a mask comprising 'deep' voxels of the tissue, while excessive erosion may result in a
mask whose extent is poorly representative of the tissue. For functional connectivity analysis,
more aggressive erosion of WM and CSF masks is recommended to reduce collinearity of WM and CSF
signal with global and GM signals. Erosion to a target range of 5 to 10 percent is recommended in
this case.::

  # Erode CSF mask to the deepest 10 percent
  confound_csf_ero[cxt]=10

  # Erode WM mask to the deepest 5 percent
  confound_wm_ero[cxt]=5

The value of ``confound_<tissue>_ero`` specifies the level of erosion that is to be applied to
tissue masks. Allowable values range from 0 to 100 and reflect the minimum percentage of tissue
remaining after erosion cycles have been applied. For instance, a value of 30 indicates that the
tissue mask should be eroded to 30 percent its original size; that is, the mask will comprise only
the deepest 30 percent of voxels with the tissue classification. (Depth is computed using
``ImageMath`` from ANTs, and the erosion is implemented in the utility ``erodespare``.)

For advanced users: The ``confound`` module offers the option of including up to three tissue- or
RoI-based regressors. While nominally these are the mean GM, WM, and CSF timeseries, it is possible
to include signals from any three RoIs for which a binary mask is available by assigning the
appropriate value to the ``<tissue>_path`` variable.

``confound_gsr``
^^^^^^^^^^^^^^^^^

*Global signal regression.*

Removal of the mean signal across the entire brain is one of the simplest and most effective means
of attenuating the influence of artefactual sources such as subject motion. While earlier studies
suggested that global signal regression might be harmful, for instance by introducing artefactual
anticorrelations (Murphy et al., 2009) or group differences (Saad et al., 2012), an emerging
consensus (e.g., Power et al., 2014; Chai et al., 2012) suggests instead that it is uniquely
effective in removing widespread forms of artefact (due to both motion and physiological processes
such as respiration).::

  # Enable GSR (recommended for functional connectivity analysis)
  confound_gsr[cxt]=mean

  # Disable GSR
  confound_gsr[cxt]=0

``confound_<tissue>_rad``
^^^^^^^^^^^^^^^^^^^^^^^^^^^

*Local/voxelwise regressors.*

In addition to standard confound regression procedures that use the same nuisance model across all
voxels, it is possible to adapt the nuisance model spatially by using voxelwise or local
regressors. For a given voxel, a local regressor can be obtained by computing the mean signal in
only WM or CSF voxels within a certain radius of that voxel (similar to the ANATICOR approach; Jo
et al., 2013). Local regression models artefactual signals present in a 4D image on a voxelwise
basis. Local white matter signal is most often used to this end (e.g., Jo et al., 2013).
``confound_<tissue>_rad`` will require a segmentation of the subject's anatomical image according
to tissue class. Modelled artefact can then be removed from the image using the REGRESS module. For
instance, this module can model each voxel's local white matter and CSF signal for subsequent
removal. Because this option requires a structural segmentation, the ``coreg`` module should
generally be run as a prerequisite.::

  # Use the local WM signal within a 20 mm radius as a voxelwise regressor
  confound_wm[cxt]=local
  confound_wm_rad[cxt]=20

  # Use the local CSF signal within a 15 mm radius as a voxelwise regressor
  confound_csf[cxt]=local
  confound_csf_rad[cxt]=15

  # Use the local mean signal within a 6 mm radius as a voxelwise regressor (don't do this)
  confound_gsr[cxt]=local
  confound_lms_rad[cxt]=6

**Caution:** If you elect to model the overall local signal (or the local GM signal), it is
*possible that you will remove more signal than noise. Spatial smoothing is thought to improve the
*signal-to-noise ratio by averaging signal in adjacent voxels. This option, by contrast, removes
*signal that is common to nearby voxels. The outcome is untested and probably dependent on the
*voxel neighbourhood size.

``confound_cc``
^^^^^^^^^^^^^^^^

*tCompCor.*

The temporal component-based correction approach (tCompCor: Behzadi et al., 2007) extracts signals
of no interest from high-variance voxels using principal component analysis (PCA). These noise
components are then added to the nuisance model. Temporal CompCor signals are extracted from the
image using ``ImageMath`` in ANTs. ``confound_cc`` must be a nonnegative integer.::

  # Disable tCompCor
  confound_cc[cxt]=0

  # Use the first 5 tCompCor components
  confound_cc[cxt]=5

Note: This option enables the temporal variance-based CompCor approach. To use the anatomical
CompCor (aCompCor) approach instead, see ``confound_gm``, ``confound_wm``, and ``confound_csf``.

``confound_past``
^^^^^^^^^^^^^^^^^^

*Expansion: previous time points.*

Including forward-shifted realignment and nuisance timeseries in the nuisance model (Friston et
al., 1996) provides a means of factoring in the subject's history of motion and for the lingering
effects of motion, which may persist for upwards of 10 seconds following motion itself.
``confound_past`` must be a nonnegative integer.::

  # Include no previous time points
  confound_past[cxt]=0

  # Include previous time point
  confound_past[cxt]=1

  # Include previous 2 time points
  confound_past[cxt]=2

Note: Do not include both previous time points (``confound_past``) and temporal derivatives
(``confound_dx``) in the same model. Together with the original time series, they form a collinear
triple, which will result in an overspecified model. That is to say, for a time series T, its
temporal derivative D, and previous/shifted time series P,

D + P = T

``confound_dx``
^^^^^^^^^^^^^^^^^

*Expansion: temporal derivatives.*

Temporal derivatives of motion parameters encode the relative displacement of the brain from one
volume of a timeseries to the next; they are used in major confound models (e.g., Satterthwaite et
al., 2012). ``confound_dx`` must be a nonnegative integer.::

  # Include no temporal derivatives
  confound_past[cxt]=0

  # Include first temporal derivative
  confound_past[cxt]=1

  # Include first and second temporal derivatives
  confound_past[cxt]=2

Note: Do not include both previous time points (``confound_past``) and temporal derivatives
(``confound_dx``) in the same model. Together with the original time series, they form a collinear
triple, which will result in an overspecified model. That is to say, for a time series T, its
temporal derivative D, and previous/shifted time series P,

D + P = T

``confound_sq``
^^^^^^^^^^^^^^^^^

*Expansion: powers (quadratic, cubic, quartic, etc.).*

In addition to the first power of each confound, you may elect to include higher powers to account
for potential noise that is proportional to squares or higher powers of motion parameters and
nuisance regressors.::

  # First power only
  confound_sq[cxt]=1

  # First power and quadratic expansion
  confound_sq[cxt]=2

  # First power, quadratic and cubic expansions
  confound_sq[cxt]=3

``confound_custom``
^^^^^^^^^^^^^^^^^^^^

*Custom regressors.*

In addition to regressors generated from the image data, custom regressors can be added to the
nuisance model. For instance, these might include respiratory traces convolved with an appropriate
response function or estimates of task-driven activity. Custom regressors should be formatted as a
matrix with regressor time series in columns and time points/frames in rows.::

  # No custom regressors
  confound_custom[cxt]=

  # Include a custom regressor file
  confound_custom[cxt]=/path/to/custom/file.1D

  # Include custom regressors in multiple files
  confound_custom[cxt]=/path/tocustom/file_1.1D,/path/to/custom/file_2.1D


``confound_rerun``
^^^^^^^^^^^^^^^^^^^

Ordinarily, each module will detect whether a particular analysis has run to completion before
beginning it. If re-running is disabled, then the module will immediately skip to the next stage of
analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you
should rerun any modules downstream of the change.::

  # Skip processing steps if the pipeline detects the expected output
  confound_rerun[cxt]=0

  # Repeat all processing steps
  confound_rerun[cxt]=1

``confound_cleanup``
^^^^^^^^^^^^^^^^^^^^^^

Modules often produce numerous intermediate temporary files and images during the course of an
analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk
space. If cleanup is enabled, any files stamped as temporary will be deleted when a module
successfully runs to completion. If a module fails to detect the output that it expects, then
temporary files will be retained to facilitate error diagnosis.::

  # Remove temporary files
  confound_cleanup[cxt]=1

  # Retain temporary files
  confound_cleanup[cxt]=0

Example configuration: 36-parameters model
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The 36-parameter confound model includes 6 realignment parameters, mean WM and CSF time series, and
global signal regression (9 parameters). Additionally, the 36-parameter model includes temporal
derivatives of these 9 time series (+9) and squares of the original 9 parameters and of their
temporal derivatives (+18) for a total of 36 parameters. As an illustrative example for
``confound`` module configuration, the variable settings for configuring a 36-parameter model are
shown here. The example configuration uses a standard 6-class segmentation, such as that output by
the ANTs Cortical Thickness pipeline when provided appropriate priors.::

  confound_rp[cxt]=1
  confound_rms[cxt]=0
  confound_gm[cxt]=0
  confound_gm_path[cxt]=${segmentation[sub]}
  confound_gm_val[cxt]=2,4
  confound_gm_ero[cxt]=5
  confound_gm_rad[cxt]=0
  confound_wm[3]=mean
  confound_wm_path[cxt]=${segmentation[sub]}
  confound_wm_val[cxt]=3
  confound_wm_ero[cxt]=5
  confound_wm_rad[cxt]=8
  confound_csf[3]=mean
  confound_csf_path[cxt]=${segmentation[sub]}
  confound_csf_val[cxt]=1
  confound_csf_ero[cxt]=5
  confound_csf_rad[cxt]=0
  confound_gsr[cxt]=mean
  confound_lms_rad[cxt]=0
  confound_cc[cxt]=0
  confound_past[cxt]=0
  confound_dx[cxt]=1
  confound_sq[cxt]=2
  confound_custom[cxt]=
  confound_rerun[cxt]=0
  confound_cleanup[cxt]=1
