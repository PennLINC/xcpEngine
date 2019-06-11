.. _scrub:

``scrub``
=========

``scrub`` module estimate the mean cbf by robust Bayesian estimation. It requires prior compute of CBF timeseries by :ref:`cbf` module 


``scrub_thresh``
^^^^^^^^^^^^^^^^^^^^
The threshold for   structural probabilty maps. The default is 0.90.::
    scrub_thresh=0.9

``scrub_wfun``
^^^^^^^^^^^^^^^^^^^^
The wavelet funtion for M-estimator. The default is `huber`. Other options include bisquare, andrews, cauchy, fair,ols, 
logistic,talwar and welsch.::
    scrub_wfun=huber

    ``Expected output``
^^^^^^^^^^^^^^^^^^^^^^
The main outputs are:: 
   - prefix_cbfscrub.nii.gz  # mean scrub cbf 