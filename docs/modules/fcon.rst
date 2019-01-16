# `fcon`: Functional connectivity module

`fcon` models the functional connectome by extracting an adjacency matrix from a voxelwise time series image. To do this, `fcon` requires a brain atlas, or a parcellation of the brain's voxels into regions of interest (network nodes). First, the local mean timeseries within each network node is extracted. The connectivity between time series is subsequently used to define the edges of an adjacency matrix over the parcellation. Currently, static connectivity is estimated using the Pearson correlation and dynamic connectivity using the multiplication of temporal derivatives (Shine et al., 2015), but alternative metrics will likely be introduced in the future.

### `fcon_atlas`

_Brain atlas or parcellation._

Contains a comma-separated list of the names of the atlases over which the functional connectome should be computed. The atlases should correspond to valid paths in `$XCPEDIR/atlas` or another appropriate `$BRAINATLAS` directory. Each atlas will be warped from its coordinate space into the analyte image space, after which the mean time series will be computed across each parcel or atlas label. `fcon` will execute for all partial string matches.

```bash
# Use the Power 264-sphere parcellation only
fcon_atlas[cxt]=power264

# Use both the Power 264 atlas and the Gordon atlas
fcon_atlas[cxt]=power264,gordon

# Use the 400-node version of the Schaefer atlas
fcon_atlas[cxt]=schaefer400

# Use all available resolutions of the Schaefer atlas
fcon_atlas[cxt]=schaefer

# Use all available atlases
fcon_atlas[cxt]=all
```

### `fcon_metric`

_Connectivity metric._

As of now, you're stuck with the Pearson correlation, so this effectively does nothing.

```bash
# Use the Pearson correlation
fcon_metric[cxt]=corrcoef
```

### `fcon_thr`

_Threshold connectome._

Sets any connections/edges with weights less than the specified number equal to 0.

```bash
# Keep all edges
fcon_thr[cxt]=N

# Remove negative edges
fcon_thr[cxt]=0

# Remove edges weaker than 0.5
fcon_thr[cxt]=0.5
```

### `fcon_window`

_Dynamic FC window length._

Specifies the window length for time-varying (dynamic) functional connectivity, in TRs, not seconds. Can also be used to disable dynamic functional connectivity computation.

```bash
# Disable dynamic FC
fcon_window[cxt]=0

# Window length of 10 TRs
fcon_window[cxt]=10
```

### `fcon_pad`

_Time series padding for dynamic FC._

Specifies whether the regional time series should be padded prior to estimation of dynamic functional connectivity. If the time series are not padded, only estimates from complete windows will be included in the dynamic model. Padding the time series will return more values for dynamic FC, but values at the beginning and end of edge-wise time series will be based on a smaller number of observations than those near the middle.

```bash
# Truncate dynamic FC to include only complete windows (DEFAULT).
fcon_pad[cxt]=TRUE

# Return n-1 observations for dynamic FC, where n is the number of TRs in the original image.
fcon_pad[cxt]=FALSE
```

### `fcon_rerun`

Ordinarily, each module will detect whether a particular analysis has run to completion before beginning it. If re-running is disabled, then the module will immediately skip to the next stage of analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you should rerun any modules downstream of the change.

```bash
# Skip processing steps if the pipeline detects the expected output
fcon_rerun[cxt]=0

# Repeat all processing steps
fcon_rerun[cxt]=1
```

### `regress_cleanup`

Modules often produce numerous intermediate temporary files and images during the course of an analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk space. If cleanup is enabled, any files stamped as temporary will be deleted when a module successfully runs to completion. If a module fails to detect the output that it expects, then temporary files will be retained to facilitate error diagnosis.

```bash
# Remove temporary files
fcon_cleanup[cxt]=1

# Retain temporary files
fcon_cleanup[cxt]=0
```
