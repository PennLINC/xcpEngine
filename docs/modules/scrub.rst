.. _scrub:

``scrub``
=========

Scrub module estimate the mean cbf by robust Bayesian estimation. It requires prior computation of CBF timeseries by :ref:`cbf` module 


``scrub_thresh``
^^^^^^^^^^^^^^^^^^^^

The threshold for structural probabilty maps. The default is 0.90.::

    scrub_thresh[cxt]=0.9

``scrub_wfun``
^^^^^^^^^^^^^^^^^^^^

The wavelet function for the  M-estimator. The default is ``huber``. Other options include bisquare, andrews, cauchy, fair,ols, 
logistic,talwar and welsch.::

    scrub_wfun[cxt]=huber



 ``Expected output``
^^^^^^^^^^^^^^^^^^^^^^

The main outputs are:: 
   - prefix_cbfscrub.nii.gz  # mean scrub cbf 
   
