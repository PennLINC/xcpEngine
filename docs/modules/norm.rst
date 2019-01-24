.. _norm:

``norm``
==========

``norm`` moves 4D  and 3D images from input bold  space into standard template, usually MNI(2mm or 1mm).
This require more disk space.


``norm_rerun``
^^^^^^^^^^^^^^^^

Ordinarily, each module will detect whether a particular analysis has run to completion before
beginning it. If re-running is disabled, then the module will immediately skip to the next stage of
analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you
should rerun any modules downstream of the change.::

  # Skip processing steps if the pipeline detects the expected output
  norm_rerun[cxt]=0

  # Repeat all processing steps
  norm_rerun[cxt]=1


``norm_cleanup``
^^^^^^^^^^^^^^^^^^

Modules often produce numerous intermediate temporary files and images during the course of an
analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk
space. If cleanup is enabled, any files stamped as temporary will be deleted when a module
successfully runs to completion. If a module fails to detect the output that it expects, then
temporary files will be retained to facilitate error diagnosis.::

  # Remove temporary files
  norm_cleanup[cxt]=1

  # Retain temporary files
  norm_cleanup[cxt]=0

``Expected output``
^^^^^^^^^^^^^^^^^^^^
The main outputs of ``norm`` include ::
  - *prefix_std.nii.gz*   the residulaised bold signal in template space
  - *prefix_maskStd.nii.gz*   the brain mask in template space
  - *prefix_referenceVolumeBrainStd.nii.gz*  reference volume brain in template space
  - *template.nii.gz*   the template image, usually MNI
Other nifti image outputs depend on derivattive outputs such `reho` and `alff`

There are quality control measures obtained to show the qulaity of registration to template space::
  - *prefix_seq2std.png* picture of coregiratipon of template and BOLD signal 
  - *prefix_normCoverage.txt* Coverage index between template and reference volume
  - *prefix_normCrossCorr.txt* Cross correlation  between template and reference volume
  - *prefix_normDice.txt* Dice Coefficient between template and reference volume
  - *prefix_normJaccard.txt*  Jaccard Coefficient between template and reference volume
