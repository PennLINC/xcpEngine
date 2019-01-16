# Anatomical processing streams

If your `FMRIPREP` output is written out in the `T1w` output space, it is already aligned to
the preprocessed `T1w` image. You can send this native space preprocessed `T1w` into the XCP
structural processing stream to

* Register it to one of our many supplied templates (including OASIS, MNI and PNC)
* Warp our many included atlases into the space of your BOLD data to extract time series
* Run structural analysis on your `T1w` images

The XCP system includes 7 standard processing streams for volumetric anatomy. These base anatomical streams are summarized below. All processing streams are heavily based on the ANTs software library. Base anatomical streams can be modified at will to suit the dataset that is to be processed. Consult module documentation for additional details.

<p align="center">
![Anatomical processing streams](%%IMAGE/streamsAnat.png "Anatomical processing streams")
</p>

 * If you are processing anatomical data exclusively to obtain references for functional processing, then minimal processing streams will produce all required references (recommended: `minimal+`, `minimal`, or `regonly`).
 * If you are interested in volumetric anatomy in and of itself, then more extensive processing streams will produce regional and voxelwise anatomical measurements (recommended: `antsct`, `complete`, or `complete+`).
 * The `regonly` stream is recommended only in cases where bias field correction and brain extraction have been computed externally.
 * Finally, the `experimental` stream contains absolutely everything, including unsupported features; use it at your own risk.

## Available modules

<p align="center">
![Anatomical processing modules](%%IMAGE/streamsAnatModules.png "Anatomical processing modules")
</p>

 * [`struc`](%%BASEURL/modules/struc)
 * [`gmd`](%%BASEURL/modules/gmd)
 * [`jlf`](%%BASEURL/modules/jlf)
 * [`roiquant`](%%BASEURL/modules/roiquant)
 * [`qcanat`](%%BASEURL/modules/qcanat)

## Processing routines

### N4 bias field correction

_Module_: [`struc`](%%BASEURL/modules/struc)

N4 bias field correction removes spatial intensity bias from the anatomical image using the N4 approach from ANTs, a variant of nonparametric nonuniform intensity normalisation.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/20378467)

### ANTs brain extraction

_Module_: [`struc`](%%BASEURL/modules/struc)

_Products:_ [`mask`](%%BASEURL/products/mask)

ANTs brain extraction combines a standard-space estimate of the probability that each voxel is a part of the brain (a brain parenchyma prior), a registration to standard space, and topological refinement in order to estimate the extent of the brain and remove non-brain voxels.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/24879923)

### ANTs registration

_Module_: [`struc`](%%BASEURL/modules/struc)

ANTs registration uses the top-performing symmetric normalisation (SyN) approach to compute a diffeomorphic function that aligns each subject's anatomy to a sample- or population-level template brain.

[Reference 1](https://www.ncbi.nlm.nih.gov/pubmed/17659998)

[Reference 2](https://www.ncbi.nlm.nih.gov/pubmed/20851191)

### Prior-guided segmentation

_Module_: [`struc`](%%BASEURL/modules/struc)

_Products:_ [`segmentation`](%%BASEURL/products/segmentation)

ANTs Atropos combines Bayesian tissue-class priors in standard space with a SyN registration and a refinement step in order to produce a high-quality segmentation of the subject's anatomy into tissue classes. Typical templates will produce a 6-class segmentation, wherein 1 corresponds to cerebrospinal fluid, 2 to cortical grey matter, 3 to cortical white matter, 4 to subcortical grey matter, 5 to cerebellum, and 6 to brainstem.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/21373993)

### Priorless segmentation

_Module_: [`struc`](%%BASEURL/modules/struc)

_Products:_ [`segmentation`](%%BASEURL/products/segmentation)

Priorless segmentation is a faster segmentation step that results in 3 tissue-class priors based on k-means clustering and refinement. For a T1-weighted image, 1 corresponds to cerebrospinal fluid, 2 corresponds to grey matter, and 3 corresponds to white matter.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/21373993)

### DiReCT cortical thickness

_Module_: [`struc`](%%BASEURL/modules/struc)

_Products:_ [`corticalThickness`](%%BASEURL/products/corticalThickness)

ANTs computes cortical thickness on a voxelwise basis in volumetric images using the DiReCT algorithm.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/24879923)

### Grey matter density

_Module_: [`gmd`](%%BASEURL/modules/gmd)

_Products:_ [`gmd`](%%BASEURL/products/gmd), [`segmentation3class`](%%BASEURL/products/segmentation3class)

Grey matter density is estimated as the probability that each voxel is assigned to the grey matter tissue class as determined via a k-means 3-class tissue segmentation and subsequent refinements.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/28432144)


### Cortical contrast*

_Module_: [`cortcon`](%%BASEURL/modules/cortcon)

_Products_: [`corticalContrast`](%%BASEURL/products/corticalContrast)

Cortical contrast is an index of the intensity contrast across the grey/white interface. Greater cortical contrast indicates that there is a sharper change from grey matter to white matter at a particular region. The voxelwise map should _never_ be used for group-level analysis; only regional values are to be used. This feature is highly experimental, unproven, and unsupported, as computations of sulcal depth are historically performed using surface-based rather than volumetric processing.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/27049014)

### Joint label fusion

_Module_: [`jlf`](%%BASEURL/modules/jlf)

_Products_: JLF MICCAI atlas

Joint label fusion produces a custom, subject-level anatomical segmentation by diffeomorphically registering an ensemble of high-quality, manually segmented images (usually 20-40 LPBA subjects) to the subject's anatomical image. A voting procedure is then applied in order to assign each voxel of the subject's brain to a single region.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/24319427)

### Regional quantification

_Module_: [`roiquant`](%%BASEURL/modules/roiquant)

Regional quantification converts voxelwise derivative maps (for instance, cortical thickness and grey matter density estimates) into regional values based on any number of provided parcellations. It is implemented in the XCP system's [`roiquant` module](%%BASEURL/modules/roiquant).

### Volume estimation

_Module_: [`roiquant`](%%BASEURL/modules/roiquant)

Estimates of global, regional, and tissue compartment volumes are computed as a part of regional quantification in the anatomical processing stream. It is implemented in the XCP system's [`roiquant` module](%%BASEURL/modules/roiquant).

### Quality assessment

_Module_: [`qcanat`](%%BASEURL/modules/qcanat)

Several indices of image quality are currently computable during anatomical processing. It is currently recommended to eschew these indices in favour of the Euler number, which has been found to perform better.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/29278774)

### Normalisation

_Module_: [`struc`](%%BASEURL/modules/struc)

Image normalisation shifts derivative maps (and potentially the primary image) into a standard sample-level or population-level space to facilitate comparisons between subjects. The normalisation step applies the transformations computed in the ANTs registration step.
