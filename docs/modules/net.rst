.. _net:

``net``
=========

``net`` performs basic analysis of networks previously computed in other modules such as ``fcon``.
``net`` operates on adjacency matrices, not images; adjacency matrices must be computed before
``net`` can be run. ``net`` computes community-related measures.
Community-based statistics will be computed using an *a priori* community
partition if one is available for the current network. Afterward, within- and between-community
connectivity measures are computed for potential use in group-level analyses.

``net_atlas``
^^^^^^^^^^^^^^^^

*Brain atlas or parcellation.*

Contains a comma-separated list of the names of the atlases over which network measures should be
computed. The atlases should correspond to valid paths in ``$XCPEDIR/atlas`` or another appropriate
``$BRAINATLAS`` directory. All atlases listed here must be run through the ``fcon`` module before
they can be used here.::

  # Use the Power 264-sphere parcellation only
  net_atlas[cxt]=power264

  # Use both the Power 264 atlas and the Gordon atlas
  net_atlas[cxt]=power264,gordon

  # Use the 400-node version of the Schaefer atlas
  net_atlas[cxt]=schaefer400

  # Use all available resolutions of the Schaefer atlas
  net_atlas[cxt]=schaefer

  # Use all available atlases
  net_atlas[cxt]=all

``net_rerun``
^^^^^^^^^^^^^^^

Ordinarily, each module will detect whether a particular analysis has run to completion before
beginning it. If re-running is disabled, then the module will immediately skip to the next stage of
analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you
should rerun any modules downstream of the change.::

  # Skip processing steps if the pipeline detects the expected output
  net_rerun[cxt]=0

  # Repeat all processing steps
  net_rerun[cxt]=1

``net_cleanup``
^^^^^^^^^^^^^^^^^

Modules often produce numerous intermediate temporary files and images during the course of an
analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk
space. If cleanup is enabled, any files stamped as temporary will be deleted when a module
successfully runs to completion. If a module fails to detect the output that it expects, then
temporary files will be retained to facilitate error diagnosis.::

  # Remove temporary files
  net_cleanup[cxt]=1

  # Retain temporary files
  net_cleanup[cxt]=0
