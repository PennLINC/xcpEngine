.. _fcon:

``fcon``
=========

``fcon`` models the functional connectome by extracting an adjacency matrix from a voxelwise time
series image. To do this, ``fcon`` requires a brain atlas, or a parcellation of the brain's voxels
into regions of interest (network nodes). First, the local mean timeseries within each network node
is extracted. The connectivity between time series is subsequently used to define the edges of an
adjacency matrix over the parcellation. Currently, static connectivity is estimated using the
Pearson correlation but alternative metrics will likely be introduced in the future.

``fcon_atlas``
^^^^^^^^^^^^^^^^

*Brain atlas or parcellation.*

Contains a comma-separated list of the names of the atlases over which the functional connectome
should be computed. The atlases should correspond to valid paths in ``$XCPEDIR/atlas`` or another
appropriate ``$BRAINATLAS`` directory. Each atlas will be warped from its coordinate space into the
analyte image space, after which the mean time series will be computed across each parcel or atlas
label. ``fcon`` will execute for all partial string matches.::

  # Use the Power 264-sphere parcellation only
  fcon_atlas[cxt]=power264

  # Use both the Power 264 atlas and the Gordon atlas
  fcon_atlas[cxt]=power264,gordon

  # Use the 400-node version of the Schaefer atlas
  fcon_atlas[cxt]=schaefer400

  # Use all available resolutions of the Schaefer atlas
  fcon_atlas[cxt]=schaefer

  # Use all available atlases
  fcon_atlas[cxt]=all


``fcon_metric``
^^^^^^^^^^^^^^^^

*Connectivity metric.*

As of now, you're stuck with the Pearson correlation, so this effectively does nothing.::

  # Use the Pearson correlation
  fcon_metric[cxt]=corrcoef

``fcon_thr``
^^^^^^^^^^^^^

*Threshold connectome.*

Sets any connections/edges with weights less than the specified number equal to 0.::

  # Keep all edges
  fcon_thr[cxt]=N

  # Remove negative edges
  fcon_thr[cxt]=0

  # Remove edges weaker than 0.5
  fcon_thr[cxt]=0.5


``fcon_rerun``
^^^^^^^^^^^^^^

Ordinarily, each module will detect whether a particular analysis has run to completion before
beginning it. If re-running is disabled, then the module will immediately skip to the next stage of
analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you
should rerun any modules downstream of the change.::

  # Skip processing steps if the pipeline detects the expected output
  fcon_rerun[cxt]=0

  # Repeat all processing steps
  fcon_rerun[cxt]=1


``fcon_cleanup``
^^^^^^^^^^^^^^^^^^^^

Modules often produce numerous intermediate temporary files and images during the course of an
analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk
space. If cleanup is enabled, any files stamped as temporary will be deleted when a module
successfully runs to completion. If a module fails to detect the output that it expects, then
temporary files will be retained to facilitate error diagnosis.::

  # Remove temporary files
  fcon_cleanup[cxt]=1

  # Retain temporary files
  fcon_cleanup[cxt]=0

``Expected output``
^^^^^^^^^^^^^^^^^^^^^^
The main outputs are:: 
   - prefix_{atlas_name}_network.txt  # correlation matrix in vector form 
   - prefix_{atlas_name}.net  # Pajek adjacency matrix
   - prefix_{atlas_name}_ts.1D  # Nodal time series
   - prefix_{atlas_name}.nii.gz # atlas in input BOLD signal space 

Other outputs depend on the issues such as poor registration of atlas to BOLD image space:: 
  - prefix_missing.txt  # index of nodes that bad, out of coverage of bold 