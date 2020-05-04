.. _jlf:


``jlf``
===========

``jlf`` is a module that  uses the ANTs Joint Label Fusion algorithm to produce a
   high-resolution anatomical segmentation of the subject’s anatomical data. Generates a
   subject-specific atlas of anatomical landmarks that can be used for regional quantification or
   network mapping. Presently, the module uses atlases of 103-OASIS labels. 


``jlf`` options 
^^^^^^^^^^^^^^^^^

If to use OASIS atlas labels with skullstrip or not::

  - jlf_extract[cxt]=1 # with skulltrip

If to keep each warped atlas, that is not advisable, it occupy space::

  - jlf_keep_warps[cxt]=0 # dont keep 

Fast joint label fusion is no recommended bcos of poor accuracy::

  - jlf_quick[cxt]=1 # for fast jlf but no recommended

The cohort of OASIS label can be selected based on their ages::

  - jlf_cohort[cxt]=All # Everyone  
  - jlf_cohort[cxt]=YoungAdult22  # Age range of 18-34
  - jlf_cohort[cxt]=Older18  # Age range of 23-90
  - jlf_cohort[cxt]=SexBalanced20  #All male subjects (ages 20-68) plus 10 of the female subjects.
  - jlf_cohort[cxt]=Subset24 # A subset for general use, slightly more balanced on sex
  - jlf_cohort[cxt]=Younger24 #Maintains the same 2:1 female:male ratio of the original, but biased towards younger subjects

Tthe number of cpu cores, the default is 2::

  - jlf_ncpu[cxt]=2

Configuring parallelisation,very fast:: 
   
  - jlf_parallel[3]=1



Outputs
^^^^^^^^
The expected outputs are::

 - prefix_Intensity.nii.gz # atlas intensity 
 - prefix_Labels.nii.gz # atlas labels
 - prefix_TargetMaskImageOr.nii.gz # target mask that cover all atlas 
 - prefix_LabelsGMIntersect.nii.gz # refined atlas with grey matter mask 
 
