# Functional connectivity streams

The XCP system includes 6 standard processing streams for functional connectivity. These base processing streams are summarized below. All processing streams draw on FSL, AFNI, and ANTs. Base processing streams can be modified at will to suit the dataset that is to be processed. Consult module documentation for additional details.

<p align="center">
![Functional connectivity processing streams](%%IMAGE/streamsFC.png "Functional connectivity processing streams")
</p>

Subject movement introduces a substantial amount of spurious variance into the BOLD signal; if data processing fails to account for the influence of motion-related variance, then artefact may subsequently be misconstrued as effect of interest. Accordingly, a number of high-performing processing streams for removing motion artefact are made available in the XCP system. Three families of denoising streams are available:

 * High-parameter streams (`36P`) combine frame-to-frame motion estimates, mean signals from white matter and cerebrospinal fluid, the mean global signal, and quadratic and derivative expansions of these signals.
   * [Reference 1](https://www.ncbi.nlm.nih.gov/pubmed/22926292)
   * [Reference 2](https://www.ncbi.nlm.nih.gov/pubmed/23994314)
 * Anatomical component-based correction (`aCompCor`) identifies sources of signal variance in white matter and cerebrospinal fluid using principal component analysis (PCA). A sufficient number of signals to explain 50 percent of variance in white matter and cerebrospinal fluid are included in the denoising model, as are motion estimates and their derivatives. Global signal regression can be enabled (`aCompCor50+gsr`) or disabled (`aCompCor50`).
   * [Reference 1](https://www.ncbi.nlm.nih.gov/pubmed/17560126)
   * [Reference 2](https://www.ncbi.nlm.nih.gov/pubmed/24657780)
 * ICA-AROMA (`aroma`) identifies sources of variance across the brain using independent component analysis (ICA), and then uses a heuristic to classify each source as either noise or signal of interest. Noise sources are included in the denoising model along with mean signal from white matter and CSF. Global signal regression can be enabled (`aroma+gsr`) or disabled (`aroma`).
   * _Note that the `aroma` streams do not strictly follow the original implementation of ICA-AROMA._ For a more faithful adaptation, see (smoothing documentation for the `aroma` module)[%%BASEURL/modules/aroma#aroma-ica-aroma-module-module-configuration-aroma_sptf-and-aroma_smo].
   * [Reference](https://www.ncbi.nlm.nih.gov/pubmed/25770991)
 * The 24-parameter stream (`24P`) is never recommended, as previous investigations have not found it to perform well.
   * [Reference 1](https://www.ncbi.nlm.nih.gov/pubmed/28302591)
   * [Reference 2](https://www.ncbi.nlm.nih.gov/pubmed/29278773)
 * All streams can be supplemented with despiking or framewise censoring.
   * [Reference 1](https://www.ncbi.nlm.nih.gov/pubmed/17490845)
   * [Reference 2](https://www.ncbi.nlm.nih.gov/pubmed/22019881)

Note that `aroma` and `acompcor` must have been performed during your preprocessing in `FMRIPREP`.

## Available modules

<p align="center">
![Functional connectivity processing modules](%%IMAGE/streamsFCModules.png "Functional connectivity processing modules")
</p>

 * [`confound`](%%BASEURL/modules/confound)
 * [`regress`](%%BASEURL/modules/regress)
 * [`reho`](%%BASEURL/modules/reho)
 * [`alff`](%%BASEURL/modules/alff)
 * [`seed`](%%BASEURL/modules/seed)
 * [`fcon`](%%BASEURL/modules/fcon)
 * [`net`](%%BASEURL/modules/net)
 * [`roiquant`](%%BASEURL/modules/roiquant)
 * [`qcfc`](%%BASEURL/modules/qcfc)

## Processing routines

### Demeaning & detrending

_Module_: [`regress`](%%BASEURL/modules/regress)

Deameaning and detrending removes the overall mean, as well as linear or polynomial trends, from the functional time series.

### Censoring or despiking

_Module_: [`regress`](%%BASEURL/modules/regress)

Censoring uses criteria such as motion estimates and signal fluctuations to flag volumes likely to be contaminated by noise, and then removes those volumes from the time series entirely. Despike uses AFNI's `3dDespike` tool to identify signal outliers on a voxelwise basis and then interpolates over those outliers.

[Reference 1](https://www.ncbi.nlm.nih.gov/pubmed/17490845)

[Reference 2](https://www.ncbi.nlm.nih.gov/pubmed/22019881)

[Reference 3](https://www.ncbi.nlm.nih.gov/pubmed/22926292)

### Mean WM / CSF signal

_Module_: [`confound`](%%BASEURL/modules/confound)

Variance in the white matter and cerebrospinal fluid compartments is typically not of interest in studies of functional connectivity. Thus, the mean signal from WM and CSF can be included in the denoising model.

### Mean global signal

_Module_: [`confound`](%%BASEURL/modules/confound)

Regression of the global signal is uniquely effective in removing widespread effects of motion and other spatially nonspecific artefacts from a functional time series.

[Reference](https://www.ncbi.nlm.nih.gov/pubmed/15110027)

### Mathematical expansions

_Module_: [`confound`](%%BASEURL/modules/confound)

Temporal derivatives and quadratic expansions are used to model delayed or nonlinear signal fluctuations attributable to artefact.

### Temporal filter

_Module_: [`regress`](%%BASEURL/modules/regress)

A temporal filter removes frequencies of no interest from the functional time series. Functional connectivity is typically driven by synchrony among low-frequency signals, so temporal filters often remove higher frequencies.

### Spatial smoothing

_Module_: [`regress`](%%BASEURL/modules/regress)

Spatial smoothing mitigates noise at the voxel level by enforcing spatial autocorrelation among adjacent voxels. By the same token, however, spatial smoothing also effectively reduces image resolution. For each selected kernel size, the pipeline will produce derivatives with that level of smoothing.

### Functional networks

_Module_: [`fcon`](%%BASEURL/modules/fcon), [`net`](%%BASEURL/modules/net)

Functional network analysis extracts mean signals from each region of a brain atlas and then estimates the degree of synchrony between each pair of regions. Functional network analysis generates a whole-brain graph; each atlas region is a node of this graph, while each synchrony estimate is an edge. Modeling the brain as a graph allows for the use of analytic tools from graph theory.

### Seed-based correlation

_Module_: [`seed`](%%BASEURL/modules/seed)

Seed-based correlation analysis computes the mean signal in a region of interest (the _seed_) and then computes the synchrony (typically operationalized as Pearson correlation) between this signal and the signal time series in each voxel.

### Regional homogeneity

_Module_: [`reho`](%%BASEURL/modules/reho)

Regional homogeneity, or ReHo, is a measure of local uniformity in the BOLD signal, operationalised as Kendall's W among each voxel and all other voxels in its neighbourhood.

### ALFF

_Module_: [`alff`](%%BASEURL/modules/alff)

ALFF is an index of the Amplitude of Low-Frequency Fluctuations in the BOLD signal.

### Regional quantification

_Module_: [`roiquant`](%%BASEURL/modules/roiquant)

Regional quantification converts voxelwise derivative maps (for instance, ReHo and ALFF estimates) into regional values based on any number of provided parcellations. It is implemented in the XCP system's [`roiquant` module](%%BASEURL/modules/roiquant).

### Quality assessment

_Module_: [`qcfc`](%%BASEURL/modules/qcfc)

Several indices of image quality are computed during functional connectivity processing at both subject and group levels. Additional details are available in the [`qcfc`](%%BASEURL/modules/qcfc) module documentation.
