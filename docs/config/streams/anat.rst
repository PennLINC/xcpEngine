.. _anatomical:

Anatomical processing streams
==============================

If your ``FMRIPREP`` output is written out in the ``T1w`` output space, it is already aligned to
the preprocessed ``T1w`` image. You can send this native space preprocessed ``T1w`` into the XCP
structural processing stream to

  * Register it to one of our many supplied templates (including OASIS, MNI and PNC)
  * Warp our many included atlases into the space of your BOLD data to extract time series
  * Run structural analysis on your ``T1w`` images

The XCP system includes 7 standard processing streams for volumetric anatomy. These base anatomical
streams are summarized below. All processing streams are heavily based on the ANTs software
library. Base anatomical streams can be modified at will to suit the dataset that is to be
processed. Consult module documentation for additional details.

Processing routines
----------------------

N4 bias field correction
^^^^^^^^^^^^^^^^^^^^^^^^^^^

*Module*: struc_

N4 bias field correction removes spatial intensity bias from the anatomical image using the N4
approach from ANTs, a variant of nonparametric nonuniform intensity normalisation.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/20378467)

ANTs brain extraction
^^^^^^^^^^^^^^^^^^^^^^

*Module*: struc_

*Products*: ``mask``

ANTs brain extraction combines a standard-space estimate of the probability that each voxel is a
part of the brain (a brain parenchyma prior), a registration to standard space, and topological
refinement in order to estimate the extent of the brain and remove non-brain voxels.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/24879923)

ANTs registration
^^^^^^^^^^^^^^^^^^^

*Module*: struc_

ANTs registration uses the top-performing symmetric normalisation (SyN) approach to compute a
diffeomorphic function that aligns each subject's anatomy to a sample- or population-level template
brain.

[Reference 1](https://www.ncbi.nlm.nih.gov/pubmed/17659998)

[Reference 2](https://www.ncbi.nlm.nih.gov/pubmed/20851191)

Prior-guided segmentation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

*Module*: struc_

*Products*: ``segmentation``

ANTs Atropos combines Bayesian tissue-class priors in standard space with a SyN registration and a
refinement step in order to produce a high-quality segmentation of the subject's anatomy into
tissue classes. Typical templates will produce a 6-class segmentation, wherein 1 corresponds to
cerebrospinal fluid, 2 to cortical grey matter, 3 to cortical white matter, 4 to subcortical grey
matter, 5 to cerebellum, and 6 to brainstem.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/21373993)

Priorless segmentation
^^^^^^^^^^^^^^^^^^^^^^^^

*Module*: struc_

*Products*: ``segmentation``

Priorless segmentation is a faster segmentation step that results in 3 tissue-class priors based on
k-means clustering and refinement. For a T1-weighted image, 1 corresponds to cerebrospinal fluid, 2
corresponds to grey matter, and 3 corresponds to white matter.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/21373993)

DiReCT cortical thickness
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

*Module*: struc_

*Products*: ``corticalThickness``

ANTs computes cortical thickness on a voxelwise basis in volumetric images using the DiReCT
algorithm.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/24879923)

Grey matter density
^^^^^^^^^^^^^^^^^^^^^

*Module*: gmd_

*Products*: ``gmd``, ``segmentation3class``

Grey matter density is estimated as the probability that each voxel is assigned to the grey matter
tissue class as determined via a k-means 3-class tissue segmentation and subsequent refinements.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/28432144)

Joint label fusion
^^^^^^^^^^^^^^^^^^^^

*Module*: ``jlf``

*Products*: JLF MICCAI atlas

Joint label fusion produces a custom, subject-level anatomical segmentation by diffeomorphically
registering an ensemble of high-quality, manually segmented images (usually 20-40 LPBA subjects) to
the subject's anatomical image. A voting procedure is then applied in order to assign each voxel of
the subject's brain to a single region.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/24319427)

Regional quantification
^^^^^^^^^^^^^^^^^^^^^^^^^^

*Module*: roiquant_

Regional quantification converts voxelwise derivative maps (for instance, cortical thickness and
grey matter density estimates) into regional values based on any number of provided parcellations.
It is implemented in the XCP system's ``roiquant`` module.

Volume estimation
^^^^^^^^^^^^^^^^^^

*Module*: ``roiquant``

Estimates of global, regional, and tissue compartment volumes are computed as a part of regional
quantification in the anatomical processing stream. It is implemented in the XCP system's
``roiquant``.

Quality assessment
^^^^^^^^^^^^^^^^^^^^

*Module*: ``qcanat``

Several indices of image quality are currently computable during anatomical processing. It is
currently recommended to eschew these indices in favor of the Euler number, which has been found
to perform better.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/29278774)

Normalization
^^^^^^^^^^^^^^^^

*Module*: [``struc``]

Image normalization shifts derivative maps (and potentially the primary image) into a standard
sample-level or population-level space to facilitate comparisons between subjects. The
normalization step applies the transformations computed in the ANTs registration step.
