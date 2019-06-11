.. _cbf:

``cbf``
=========

``cbf`` module computes the mean CBF and CBF timeseries by subtracting label-conttol pairs and modeled  by the kinetic model. 
The module requires some parameters to be specified and standard parameters are supplied if those parameters are not provided. 


``cbf_first_tagged``
^^^^^^^^^^^^^^^^^^^^

*Volume label*
The `cbf_first_tagged` identifies which pair of volume is label or control volume. 
If `cbf_first_tagged is 1, that means the first of pair volume is label and the second is control and vice versa.::

  # the first volume is label
  cbf_first_tagged[cxt]=1

  # the first volume is control
  cbf_first_tagged[cxt]=0


``cbf_perfusion``
^^^^^^^^^^^^^^^^

*Labelling approach methods.*

As of now, only two popular label strategies are implemente in xcpEngine .::

  # for pulsed ASL (PASL)
  cbf_perfusion[cxt]=pasl

  # for pseudio-continous ASL (CASL/PASL) 
  cbf_perfusion[cxt]=casl 

PASL is default if none is supply. 

``cbf_m0_scale``
^^^^^^^^^^^^^

*M0 scale.*

If the M0 scan is included and acquired at different scale to ASL acquisition, the user can supply the M0 scale.
if there is no M0, `cbf_m0_scale` is set to 1, and average control volume is used as reference::

  # scale
  cbf_m0_scale[cxt]=1


``cbf_lambda``
^^^^^^^^^^^^^^
The lambda is the blood-brain partition coefficient that scales the signal intentisty of the tissues to that of the blood.
The common or standard value is ƛ=0.90 ml/g.::

  # 
  cbf_lambda[cxt]=0.9


``cbf_pld``, ``cbf_tau``
^^^^^^^^^^^^^^^^^^^^^^^
These two parameters are applicable to only CASL/PCASL. the cbf_tau is the label duration and cbf_pld is the post
 labeling delay time. Both are expressed in seconds.::

  # 
  cbf_tau[cxt]=1.8
  cbf_pld[cxt]=1.8 


``cbf_t1blood``, ``cbf_alpha``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

`cbf_t1blood` is the longitutdinal relaxation time of the blood in seconds and the standard value denpends on the  field strength of MRI machine. 
For 3T and 1.5T, the standard `cbf_t1blood` values are 1.650s and 1.350s respectively. The `cbf_alpha` is the labelling efficiency and values are
different for PASL and CASL/PCASL. The standard value is 0.85 for CASL/PCASL and 0.98 for PASL.::
  # 
  cbf_t1blood[cxt]=1.65 # for 3T MRI
  cbf_alpha[cxt]=0.85 # for PCASL  


``Expected output``
^^^^^^^^^^^^^^^^^^^^^^
The main outputs are:: 
   - prefix_meanPerfusion.nii.gz  # mean perfusion
   - prefix_perfusion.nii.gz  # perfusion timeseries
   - prefix_negativeVoxels.txt  # number of negative voxels, part of QC
 