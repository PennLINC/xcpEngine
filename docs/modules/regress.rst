# `regress`: Confound/nuisance regression module

`regress` executes multiple linear regression to fit any confound time series computed using the `confound` module to the time series of each voxel in the analyte image. Any variance in the BOLD time series that is explained by the confound model is discarded from the analyte image. The residuals (unexplained variance) of the BOLD time series are retained as the denoised image. `regress` additionally supports temporal filtering, censoring (configured in `prestats` and executed in `regress`), and production of smoothed derivative time series.

### `regress_tmpf`

_Temporal filtering parameters._

Bandpass filtering the analyte time series but not nuisance regressors re-introduces noise-related variance at removed frequencies when the time series is residualised with respect to the regressors via linear fit (Hallquist et al., 2014). (The XCP Engine is designed so as to make this involuntary reintroduction of noise impossible.) Instead, the recommended approach is filtering both the time series and the nuisance regressors immediately prior to fitting and residualisation (Hallquist et al., 2014).

```bash
# Gaussian filter
regress_tmpf[cxt]=gaussian

# FFT filter
regress_tmpf[cxt]=fft

# Second-order Butterworth filter
regress_tmpf[cxt]=butterworth
regress_tmpf_order[cxt]=2
regress_tmpf_pass[cxt]=2

# First-order Chebyshev I filter with pass-band ripple 0.5
regress_tmpf[cxt]=chebyshev1
regress_tmpf_order[cxt]=1
regress_tmpf_pass[cxt]=2
regress_tmpf_ripple[cxt]=0.5

# First-order elliptic filter with pass-band ripple 0.5 and stop-band ripple 20
regress_tmpf[cxt]=elliptic
regress_tmpf_order[cxt]=1
regress_tmpf_pass[cxt]=2
regress_tmpf_ripple[cxt]=0.5
regress_tmpf_ripple2[cxt]=20
```

 * _FFT_-based filters, as implemented in AFNI's `3dBandpass`, use a fast Fourier transform to attenuate frequencies. An FFT-based filter may not be suitable for use in designs that incorporate iterative motion censoring, since it will include interpolated frequencies in its calculations."
 * A _Gaussian_ filter, as implemented in FSL, uses a Gaussian-weighted least-squares fit to remove frequencies of no interest from the data. This filter has a very slow frequency roll-off.
 * _Chebyshev_ and _elliptic_ filters more ideally discriminate accepted and attenuated frequencies than do _Butterworth_ filters, but they introduce ripples in either the passband (Chebyshev I), stopband (Chebyshev II), or both (elliptic) that result in some signal distortion.
 * `regress_tmpf_order` specifies the filter order. (Relevant only for Butterworth, Chebyshev, and elliptic filters.)
 * `regress_tmpf_pass` specifies whether the filter is forward-only (`regress_tmpf_pass[cxt]=1`, analogous to `filter` or `lfilter` in NumPy or MATLAB) or forward-and-reverse (`regress_tmpf_pass[cxt]=2`, analogous to `filtfilt` in NumPy or MATLAB, recommended). (Relevant only for Butterworth, Chebyshev, and elliptic filters.)
 * `regress_tmpf_ripple` specifies the pass-band ripple, while `regress_tmpf_ripple2` specifies the stop-band ripple. (`ripple` relevant only for Chebyshev I or elliptic filter, `ripple2` relevant only for Chebyshev II or elliptic filter.)

### `regress_hipass` and `regress_lopass`

_Temporal filter cutoff frequencies._

Any frequencies below the low-pass cutoff and above the high-pass cutoff will be counted as pass-band frequencies; these will be retained by the filter when it is applied.

Functional connectivity between regions of interest is typically determined on the basis of synchrony in low-frequency fluctuations (Biswal et al., 1995); therefore, removing higher frequencies using a low-pass filter may effectively remove noise from the time series while retaining signal of interest. For a contrasting view, see Boubela et al. (2013). Set `regress_lopass` to `n` (Nyquist) to allow all low frequencies to pass.

```bash
# Band-pass filter with pass-band 0.01-0.08 Hz
regress_hipass[cxt]=0.01
regress_lopass[cxt]=0.08

# High-pass-only filter (>0.01 Hz)
regress_hipass[cxt]=0.01
regress_lopass[cxt]=n

# Low-pass-only filter (<0.1 Hz)
regress_hipass[cxt]=0
regress_lopass[cxt]=0.1
```

High-pass filters can be used to remove very-low-frequency drift from an acquisition; this is a form of scanner noise. The demean/detrend option additionally removes linear and polynomial drift. Set `regress_hipass` to 0 to allow all high frequencies to pass.

### `regress_sptf` and `regress_smo`_Spatial smoothing parameters._

Endemic noise, for instance due to physiological signals or scanner activity, can introduce spurious or artefactual results in single voxels. The effects of noise-related artefacts can be mitigated by spatially filtering the data, thus dramatically increasing the signal-to-noise ratio. However, spatial smoothing is not without its costs: it effectively reduces volumetric resolution by blurring signals from adjacent voxels. The spatial smoothing implemented in the `regress` module (i) keeps the unsmoothed analyte image for downstream use and (ii) creates a derivative image that is smoothed using the specified kernel. This allows either the smoothed or the unsmoothed version of the image to be used in any downstream modules as appropriate.
 
```bash
# No smoothing
regress_sptf[cxt]=none
regress_smo[cxt]=0

# Gaussian kernel (fslmaths) of FWHM 6 mm
regress_sptf[cxt]=gaussian
regress_smo[cxt]=6

# SUSAN kernel (FSL's SUSAN) of FWHM 4 mm
regress_sptf[cxt]=susan
regress_smo[cxt]=4

# Uniform kernel (AFNI's 3dBlurToFWHM) of FWHM 5 mm
regress_sptf[cxt]=uniform
regress_smo[cxt]=5
```

`regress_sptf` specifies the type of spatial filter to apply for smoothing, while `regress_smo` specifies the full-width at half-maximum (FWHM) of the smoothing kernel in mm.

 * Gaussian smoothing applies the same Gaussian smoothing kernel across the entire volume.
 * SUSAN-based smoothing restricts mixing of signals from disparate tissue classes (Smith and Brady, 1997).
 * Uniform smoothing applies smoothing to all voxels until the smoothness computed at every voxel attains the target value.
 * Uniform smoothing may be used as a compensatory mechanism to reduce the effects of subject motion on the final processed image (Scheinost et al., 2014).

### `regress_rerun`

Ordinarily, each module will detect whether a particular analysis has run to completion before beginning it. If re-running is disabled, then the module will immediately skip to the next stage of analysis. Otherwise, any completed analyses will be repeated.If you change the run parameters, you should rerun any modules downstream of the change.

```bash
# Skip processing steps if the pipeline detects the expected output
regress_rerun[cxt]=0

# Repeat all processing steps
regress_rerun[cxt]=1
```

### `regress_cleanup`

Modules often produce numerous intermediate temporary files and images during the course of an analysis. In many cases, these temporary files are undesirable and unnecessarily consume disk space. If cleanup is enabled, any files stamped as temporary will be deleted when a module successfully runs to completion. If a module fails to detect the output that it expects, then temporary files will be retained to facilitate error diagnosis.

```bash
# Remove temporary files
regress_cleanup[cxt]=1

# Retain temporary files
regress_cleanup[cxt]=0
```

### `regress_process`

Specifies the order for execution of filtering and regression. Bandpass filtering the analyte time series but not nuisance regressors re-introduces noise-related variance at removed frequencies when the time series is residualised with respect to the regressors via linear fit (Hallquist et al., 2014). Thus, effective denoising requires either that confound regression be performed prior to temporal filtering or that both the analyte time series and all confound time series be subjected to the same temporal filter in order to prevent frequency mismatch.

Format `regress_process` as a string of concatenated three-character routine codes separated by hyphens (`-`).

 * `REG-TMP` instructs the module to perform confound regression prior to temporal filtering.
 * `TMP-REG` instructs the module to perform temporal filtering prior to confound regression. If this option is set, then both the analyte time series and all confound time series will be filtered. This option is typically preferable to `REG-TMP` because it determines the confound fit using only the frequencies of interest.
 * Censoring is always performed *after* both filtering and regression.

```bash
# Regression first ('REGBP' in Hallquist et al., 2014)

# Temporal filtering first (equivalent to 'Simult' in Hallquist et al., 2014)
```
