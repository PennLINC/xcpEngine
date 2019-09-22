.. _scorescrub:

``scorescrub``
==============

``scorescrub`` module detects and discards oultier cbf volumes and robust Bayesian estimation of 
CBF by removing the white noise as opposed to outlier rejection. It requires prior run of :ref:`cbf` module  


``score_thresh``
^^^^^^^^^^^^^^^^^^^^
The threshold for   structural probabilty maps. The default is 0.90.::
  scorescrub_thresh=0.9

``Expected output``
^^^^^^^^^^^^^^^^^^^^^^
The main outputs are:: 
   - prefix_cbfscore.nii.gz  # mean score cbf 
   - prefix_cbfscore_ts.nii.gz  # cbf time series after discarding the volumes that might contribute to artifact
   - prefix_cbfscoreR.nii.gz  # relative mean score cbf 
   - prefix_cbfscoreZ.nii.gz  # zscore mean score cbf 
   - prefix_cbfsrub.nii.gz  # mean scrub cbf 
   - prefix_cbfscrubR.nii.gz  # relative mean scrub cbf 
   - prefix_cbfscrubZ.nii.gz  # zscore mean scrub cbf
   - prefix_sub-1_cbfscore_tsnr.nii.gz # temporal signal to noise ratio of cbf score 
   

  