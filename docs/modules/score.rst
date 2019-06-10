. _score:

``score``
=========

``score`` module detects and discards oultier cbf volumes. It requires prior run of :ref:`cbf` module 


``score_thresh``
^^^^^^^^^^^^^^^^^^^^
The threshold for   structural probabilty maps. The default is 0.90.::
    score_thresh=0.9

``Expected output``
^^^^^^^^^^^^^^^^^^^^^^
The main outputs are:: 
   - prefix_cbfscore.nii.gz  # mean score cbf 
   - prefix_cbfscorets.nii.gz  # cbf time series after discarding the volumes that might contribute to artifact
  