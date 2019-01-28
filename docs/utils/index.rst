Utilities
===========

Unlike modules and functions, _utilities_ are standalone image processing scripts that have been
designed for use both inside and outside the pipeline context. Some utilities are wrapper scripts
that combine binaries from ANTs, FSL, and AFNI to simplify certain functionalities. Other utilities
are R scripts that provide functionalities outside of other common image processing libraries.

There are many undocumented utilities if you look in the code. Listed below are the
documented utilities.

Denoising and data quality
--------------------------
 * :ref:`qcfc` : a utility for quality control measures of functional connectitivty
 * :ref:`qcfcDistanceDependence` : a utility to determine the distance dependence of motion
   artifact on functinal connectivity.

Image utilities: voxelwise and regional
--------------------------

 * :ref:`erodespare`
