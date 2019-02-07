.. _erodespare:

Erodespare
==================

*Label erosion tool.*

``erodespare`` erodes a subset of labels (or range of values) in a provided image such that only
the deepest k percent of voxels in the label set are retained. ``erodespare`` *erodes* an image
while *sparing* the deepest voxels. This can be a useful tool for generating tissue maps for
nuisance regression in a way that minimizes partial volume effects and decreases the correlation
between tissue-based nuisance regressors and the global signal.

``erodespare`` executes in the following order, using its inputs as follows:

 1. Read in the image specified by the ``-i`` flag
 2. Binarise the image such that voxels with the values specified by the ``-v`` flag are set to 1
    while all other voxels are set to 0.
 3. Compute a fractional depth map such that, for instance, a voxel in the 33rd percentile of
    deepest voxels is assigned a value of 33
 4. Threshold the depth map according to the criterion set by the ``-r`` flag.
    (This is the erosion step.)
 5. Binarise the map and write the eroded mask to the path specified by ``-o``

Output
-------

A binary-valued mask indicating whether each voxel belongs to a specified label set following
erosion to the deepest k percent.

Input arguments
-----------------

``-i``: Input mask
~~~~~~~~~~~~~~~~~~~~~

A mask, image, or label set that the user wishes to erode.

``-o``: Output path
~~~~~~~~~~~~~~~~~~~~~~

A path in a valid directory, where the eroded map will be written once it is computed.

Optional input arguments
-------------------------

``-r``: Retention criterion
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*Default value: 5 percent*

The percent of voxels that should be retained in the eroded mask. The argument should be a percent
value, not a fractional value (e.g., ``5`` not ``0.05`` for 5 percent). For instance, a value of
``5`` will erode all but the deepest 5 percent of voxels. (At least 5 percent of voxels will be
preserved.)

``-v``: Value set
~~~~~~~~~~~~~~~~~~~

If this variable is defined, then the specified range of labels will be extracted from the provided
mask prior to erosion. For instance, ``-v 2,4`` will extract cortical and deep grey matter from a
standard 6-class segmentation. Syntax follows the ``-v`` specification in ``val2mask``. If this
option is not provided, then a mask comprising all nonzero values from the input will be generated
and eroded.

``-n``: Intermediate output path
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A path where ``erodespare`` stores temporary files. If your machine or file system has a designated
space for temporary files (e.g., ``/tmp``), then using this space can substantially improve I/O
speed.
