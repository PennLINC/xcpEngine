# `qcfc`: Quality control module for functional connectivity

`qcfc` computes benchmark measures for a functional connectivity processing stream. Measures include (i) QC-FC correlations of functional connections with motion (number and fraction of related edges and absolute median correlation), (ii) distance-dependence of residual motion artefact, (iii) an estimate of the degrees of freedom lost through denoising procedures, and (iv) voxelwise activation timeseries plots for a set of example subjects. `qcfc` is divided into subject-level and group-level modules. The subject-level module collates subject-level estimates of data quality and produces the voxelwise plot, while the group-level module computes QC-FC correlations and distance-dependence.

### `qcfc_atlas`

_Brain atlas or parcellation._

Contains a comma-separated list of the names of the atlases over which QC-FC correlations should be computed. The atlases should correspond to valid paths in `$XCPEDIR/atlas` or another appropriate `$BRAINATLAS` directory. All atlases listed here must be run through the `fcon` module before they can be used here.

```bash
# Use the Power 264-sphere parcellation only
qcfc_atlas[cxt]=power264

# Use both the Power 264 atlas and the Gordon atlas
qcfc_atlas[cxt]=power264,gordon

# Use the 400-node version of the Schaefer atlas
qcfc_atlas[cxt]=schaefer400

# Use all available resolutions of the Schaefer atlas
qcfc_atlas[cxt]=schaefer

# Use all available atlases
qcfc_atlas[cxt]=all
```

### `qcfc_sig`

_Correction for multiple comparisons._

Because QC-RSFC correlations are computed at every edge in each graph, the chance of non-significant results being falsely reported as significant is elevated in proportion to the number of edges. The risk of false positives can be reduced by taking into account the number of comparisons being made and applying a correction to the reported p-values. Correction for multiple comparisons can be based either on the Bonferroni correction (strictest) or on the false discovery rate.

```bash
# Use the false discovery rate
qcfc_sig[cxt]=fdr

# Use Bonferroni correction
qcfc_sig[cxt]=bonferroni

# No correction for multiple comparisons
qcfc_sig[cxt]=none
```

### `qcfc_custom`

_Custom time series for plot._

When the `qcfc` module produces a voxelwise time series plot for each subject (Power, 2017), by default it also plots framewise motion estimates and DVARS for reference. These default plots can be supplemented with custom time series provided by the user. For instance, if task-constrained connectivity is being computed, it could be useful to include a plot the framewise task model. `qcfc_custom` should be formatted as `<name of time series>:<path to 1D file containing time series>:<threshold for acceptable quality>`, using the colon as delimiter. If a threshold is not appropriate for the current time series, then format as `<name of time series>:<path to 1D file containing time series>`.

```bash
# No custom time series
qcfc_custom[cxt]=

# Plot a framewise task model
qcfc_custom[cxt]=task:/path/to/task/estimate.1D

# Plot a framewise task model specified in the cohort variable tstask
qcfc_custom[cxt]=task:${tstask[sub]}

# Separately plot two different task models
qcfc_custom[cxt]=task1:${tstask1[sub]},task2:${tstask2[sub]}
```

### `qcfc_confmat` and `qcfc_conformula`

_QC-FC: Covariates and model._

When QC-RSFC correlations (motion-connectivity correlations) are computed, any covariates specified here will be included in the model. This can help to disentangle the effects of motion from those of variables that are often related to motion, such as age and sex.

The covariates file (`qcfc_confmat`) should be formatted as a `.csv` file that includes a header specifying variable names. Each subject's identifying variables (fields in the main cohort file that do not correspond to images or files) should be included, as should covariate values for each subject. Fields should be comma-separated. An example is provided below. The covariate model (`qcfc_conformula`) should be formatted as a valid R formula. Any categorical variables (e.g., diagnosis) should be specified as a factor. It is not necessary to specify the inclusion of subject motion in the model; motion will always be included.

```bash
# No covariates
qcfc_confmat[cxt]=
qcfc_conformula[cxt]=

# Use age and diagnosis as covariates
qcfc_confmat[cxt]=/path/to/covariates/file.csv
qcfc_conformula[cxt]=age+factor(diagnosis)
```

#### Example covariates file

The contents of an example covariates file are provided here. Any identifier columns present in the cohort file must also be present in the covariates file (here, `id0` and `id1`). Remaining columns in the 

```
id0,id1,age,sex
ACC,001,217,0
ACC,002,238,1
ACC,003,238,1
DSQ,001,154,0
CAT,001,176,1
```

### `qcfc_rerun`

Ordinarily, each module will detect whether a particular analysis has run to completion before beginning it. If re-running is disabled, then the module will immediately skip to the next stage of analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you should rerun any modules downstream of the change.

```bash
# Skip processing steps if the pipeline detects the expected output
qcfc_rerun[cxt]=0

# Repeat all processing steps
qcfc_rerun[cxt]=1
```

### `qcfc_cleanup`

Modules often produce numerous intermediate temporary files and images during the course of an analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk space. If cleanup is enabled, any files stamped as temporary will be deleted when a module successfully runs to completion. If a module fails to detect the output that it expects, then temporary files will be retained to facilitate error diagnosis.

```bash
# Remove temporary files
qcfc_cleanup[cxt]=1

# Retain temporary files
qcfc_cleanup[cxt]=0
```
