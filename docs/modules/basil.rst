. _basil:

``basil``
=========

``basil`` module computes the CBF and the derivatives using Bayesian inference method for the kinetic model inversion. It also part of FSL and
can aslo be run independently. 


``basil_perfusiion`
^^^^^^^^^^^^^^^^^^^^
*Labelling approach methods.*

As of now, only two popular label strategies are implemented:.::

  # for pulsed ASL (PASL)
  basil_perfusion[cxt]=pasl

  # for pseudio-continous ASL (CASL/PASL) 
  basil_perfusion[cxt]=casl 

PASL is default if none is supply.
 
 ``basil_inputformat``
^^^^^^^^^^^^^^^^
*Volume label*
The `basil_inputformat` identifies which pair of volume is label or control volume. 
There are three types- tc (label-control), ct(control-label) and diff (cbf).::

  # the first volume is label
  basil_inputformat[cxt]=tc

  # the first volume is control
  basil_inputformat[[cxt]=ct

 # each volume is cbf
  basil_inputformat[[cxt]=diff


``basil_spatial``,``basil_pvc``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If the spatial regulaization (basil_spatial) by kernel  and  the partial 
voulme correction (basil_pvc) are require, they are set to 1s or otherwise 0s ::

  # spatial regulaization
  basil_spatial[cxt]=1

  # Partial volume correction
  basil_pvc[cxt]=1 

``basil_m0_scale``
^^^^^^^^^^^^^

*M0 scale.*

If the M0 scan is included and acquired at different scale to ASL acquisition, the user can supply the M0 scale.
if there is no M0, `basil_m0_scale` is set to 1, and average control volume is used as reference/M0::

  # scale
  basil_m0_scale[cxt]=1


``basil_lambda``
^^^^^^^^^^^^^^
The lambda is the blood-brain partition coefficient that scals the signal intentisty of tissues to that of blood.
The common or standard value is ƛ=0.90 ml/g.::

  # 
  basil_lambda[cxt]=0.9


``basil_pld`` and ``basil_tis``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
These are  applicable to only CASL/PCASL. `basil_pld` is the post
 labeling delay time in seconds and basil_tis is the invertion time. The invetion time 
 is sometime the sum of label duration and post labelling delay. BASIL accepts multiple pld and tis 
 separated by commas::

  # single pld
  basil_pld[cxt]=1.8 
  basil_tis[cxt]=3.6 # this implies label duration is 1.8 scale

  # multiple plds 
  basil_pld[cxt]=0.25,0.5,1,1.5
  basil_tis[cxt]=2.05,2.55,3.55,5.05 # this implies label duration is 1.8 scale

``basil_t1blood``, ``basil_alpha``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

`basil_t1blood` is the longitutdinal relaxation tume of blood in seconds and the standard value denpend on the  field strength of MRI machine. 
For 3T and 1.5T, the standard `cbf_t1blood` values are 1.650s and 1.350s respectively. The `basil_alpha` is the labelling efficiency and values are
different for PASL and CASL/PCASL. The standard value is 0.85 for CASL/PCASL and 0.08 for PASL.::
  # 
  basil_t1blood[cxt]=1.65 # for 3T MRI
  basil_alpha[cxt]=0.85 # for PCASL  

``basil_MOTR``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
This is for the TR of MO scan if it is available. It is very important for the purpose of calibration and also account foe shorter TR value.
the default is 3.2s but it also read from the MO scan image.  


``Expected output``
^^^^^^^^^^^^^^^^^^^^^^
The main outputs are:: 
   - prefix_cbf_basil.nii.gz  # mean basil cbf 
   - prefix_cbf_basil_pv.nii.gz  # partial volume corrected cbf 
   - prefix_cbf_basil_spatial.nii.gz  # spatial regularized cbf 
 