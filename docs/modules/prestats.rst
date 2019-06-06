.. _prestats:

``prestats``
=============

``prestats`` was previously an omnibus module for the preprocessing of functional MR images. The
functionality of ``prestats`` is mostly covered by ``FMRIPREP``.

``prestats`` requries a line in the design file that indicates the input image is from
``FMRIPREP`` ouput::

    # input bold signal is from FMRIPREP output
     prestats_process[cxt]=FMP


The ``prestats`` outputs are derived directly from the ``FMRIPREP``. The expected outputs include::
    - ``prefix_preprocessed.nii.gz``: Bold signal
    - ``prefix_referenceVolume.nii.gz``: reference volume with skull
    - ``prefix_referenceVolumeBrain.nii.gz``: reference volume without skull
    - ``prefix_segmenation.nii.gz``: segmentation tissues
    - ``prefix_struct.nii.gz``: T1w image
    - ``prefix_mask.nii.gz``: brain mask
    - ``prefix_fmriconf.tsv``: confound regressors from ``FMRIPREP`

All  ``*nii.gz`` are expected to be have the same voxel size as the input but may have their
orientation changed to the FSL standard.

The ``prestats`` outputs also consist of Quality Assesmment between structrual and BOLD images::
    - ``prefix_coregCoverage.txt`` : Coverage index
    - ``prefix_coregCrossCorr.txt`` : Cross correlation
    - ``prefix_coregDice.txt`` : Dice index
    - ``prefix_coregJaccard.txt`` : Jaccard index 
