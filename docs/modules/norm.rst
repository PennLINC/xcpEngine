.. _norm:

``norm``
==========

``norm`` moves 4D timeseries from acquisition space into a standard space. It is only compatible
with ITK-/ANTs-based transforms at this time. Before running normalisation, you must run
coregistration to compute a transformation from the subject's functional image to the subject's
anatomical image. It may also be necessary to compute a warp from the subject's anatomical image to
a template in the target standard space.

This module is not configurable at this time. Near-term customisability includes:

 * A multiplicity of target spaces for registrations
 * The option to disable registration of the primary analyte (since this often unnecessarily
   consumes disk space) and normalise only derivative images

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
