.. _roiquant:

``roiquant``
===============

``roiquant`` performs ROI-wise quantification of voxelwise metrics. For each provided atlas or
parcellation of the brain, it produces a table of values for each region of that parcellation.
While many modules include internal routines for ROI-wise statistics, this module centralises all
ROI-wise measures in a single routine. It accepts any number of ROI maps or parcellations, then
computes, for each voxelwise metric, the mean across all voxels in each ROI of each provided
parcellation.

``roiquant_atlas``
^^^^^^^^^^^^^^^^^^^^^^

*Brain atlas or parcellation.*

Contains a comma-separated list of the names of the atlases over which regional values should be
computed. The atlases should correspond to valid paths in ``$XCPEDIR/atlas`` or another appropriate
``$BRAINATLAS`` directory.::

  # Use the Power 264-sphere parcellation only
  roiquant_atlas[cxt]=power264

  # Use both the Power 264 atlas and the Gordon atlas
  roiquant_atlas[cxt]=power264,gordon

  # Use the 400-node version of the Schaefer atlas
  roiquant_atlas[cxt]=schaefer400

  # Use all available resolutions of the Schaefer atlas
  roiquant_atlas[cxt]=schaefer

  # Use all available atlases
  roiquant_atlas[cxt]=all

``roiquant_globals``
^^^^^^^^^^^^^^^^^^^^^^^^^^

*Compute mean values over the brain and tissue compartments.*

It is also possible to compute the average values over voxels in the entire brain and over voxels
in each tissue compartment from a provided anatomical segmentation (e.g., white matter, grey
matter, CSF). The flag ``roiquant_globals`` instructs the ``roiquant`` module whether these values
should also be tabulated.::

  # Include global means
  roiquant_globals[cxt]=1

  # Do not include global means
  roiquant_globals[cxt]=0

``roiquant_vol``
^^^^^^^^^^^^^^^^^^^

*Compute parcel volumes.*

The volume of each parcel can be computed by registering the parcellation or atlas into the
subject's native space, counting the number of voxels in each parcel, and finally multiplying the
number of voxels by the voxel dimension. This can be more useful for parcellations that are
data-driven, such as those produced by atlas fusion techniques.::

  # Compute volumes
  roiquant_vol[cxt]=1

  # Do not compute volumes
  roiquant_vol[cxt]=0

``roiquant_rerun``
^^^^^^^^^^^^^^^^^^^^^^^^

Ordinarily, each module will detect whether a particular analysis has run to completion before
beginning it. If re-running is disabled, then the module will immediately skip to the next stage of
analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you
should rerun any modules downstream of the change.::

  # Skip processing steps if the pipeline detects the expected output
  roiquant_rerun[cxt]=0

  # Repeat all processing steps
  roiquant_rerun[cxt]=1

``roiquant_cleanup``
^^^^^^^^^^^^^^^^^^^^^^

Modules often produce numerous intermediate temporary files and images during the course of an
analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk
space. If cleanup is enabled, any files stamped as temporary will be deleted when a module
successfully runs to completion. If a module fails to detect the output that it expects, then
temporary files will be retained to facilitate error diagnosis.::

  # Remove temporary files
  roiquant_cleanup[cxt]=1

  # Retain temporary files
  roiquant_cleanup[cxt]=0
