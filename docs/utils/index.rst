Utilities
===========

Unlike :ref:`modules`, *utilities* are standalone image processing scripts that have been designed
for use both inside and outside the pipeline context. Some utilities are wrapper scripts that
combine binaries from ANTs, FSL, and AFNI to simplify certain functionalities. Other utilities are
R scripts that provide functionalities outside of other common image processing libraries.

There are many undocumented utilities if you look in the code. Listed below are the
documented utilities.

Denoising and data quality
--------------------------

 * :ref:`qcfc` : a utility for quality control measures of functional connectitivty
 * :ref:`qcfcDistanceDependence` : a utility to determine the distance dependence of motion
   artifact on functinal connectivity.
 * :ref:`combineoutput` :  a utility for combining the output of  all subjects simiar file into one file for further analysis in other platform such as Excel, matlab, SPSS, R etc.

Image utilities: voxelwise and regional
-----------------------------------------
 * :ref:`seedconnectivity`: This computes functional connectitivty between a region
 or mask and all voxels with in the brain. 
 * :ref:`erodespare` : This can be a useful tool for generating tissue maps for
nuisance regression in a way that minimizes partial volume effects
 * :ref:`roiquants`:  This tool allows users to use customed atlases to generate region values



.. toctree::
   :maxdepth: 1

   combineoutput
   qcfc
   qcfcDistanceDependence
   seedconnectivity
   roiquants
   erodespare
