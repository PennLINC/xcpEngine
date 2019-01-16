# `gmd`: Grey matter density module

`gmd` computes a voxelwise grey matter density map [based on previous work by Dr. Stathis Gennatas and colleagues](https://www.ncbi.nlm.nih.gov/pubmed/28432144). Grey matter density is loosely defined as the probability that each voxel is a part of the grey matter as determined using an iterative, priorless segmentation in ANTs Atropos.

The `gmd` module is operational but not configurable.

### `gmd_rerun`

Ordinarily, each module will detect whether a particular analysis has run to completion before beginning it. If re-running is disabled, then the module will immediately skip to the next stage of analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you should rerun any modules downstream of the change.

```bash
# Skip processing steps if the pipeline detects the expected output
gmd_rerun[cxt]=0

# Repeat all processing steps
gmd_rerun[cxt]=1
```

### `gmd_cleanup`

Modules often produce numerous intermediate temporary files and images during the course of an analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk space. If cleanup is enabled, any files stamped as temporary will be deleted when a module successfully runs to completion. If a module fails to detect the output that it expects, then temporary files will be retained to facilitate error diagnosis.

```bash
# Remove temporary files
gmd_cleanup[cxt]=1

# Retain temporary files
gmd_cleanup[cxt]=0
```
