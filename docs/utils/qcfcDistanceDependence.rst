# `qcfcDistanceDependence`

_Distance-dependence of QC-FC measures._

`qcfcDistanceDependence` computes the distance-dependence of QC-FC relationships previously estimated using `qcfc`. (Although it was designed for diagnosing the distance-dependent profile of motion artefact, `qcfcDistanceDependence` can be used to compute the distance-dependence of any edgewise measure.)

`qcfcDistanceDependence` executes in the following order, using its inputs as follows:

 1. Read in the atlas specified by the `-a` flag.
 2. Call `cmass` to estimate the centre of mass of each node in the atlas.
 3. Call `distmat` to estimate the pairwise Euclidean distance between nodal centres of mass, saving the output as a distance matrix to the path specified by the argument to `-d`.
 4. Correlate the computed pairwise distances with the test values provided as an argument to `-q`, saving the overall correlation to the path specified by the argument to `-o`.
 5. Plot a cloud of edgewise values with the Euclidean distance on the abscissa and with the test value on the ordinate; write the plot to the path specified by the argument to `-f`.

### Output

 * The distance-dependence of provided test values, defined as the edgewise correlation coefficient between the test values and Euclidean distance (specified by argument to `-o`).
 * A matrix of internodal Euclidean distances (specified by argument to `-d`).
 * A plot of the relationship between test values and Euclidean distances (specified by argument to `-f`).

### Input arguments

```
${XCPEDIR}/utils/qcfcDistanceDependence –a <atlas> -q <test values> -o <output path> [-d <output distance matrix> -f <output correlation plot> -i <intermediate output>]
```

Optional arguments are denoted in square brackets ([]).

#### `-a`: Atlas

The atlas over which inter-nodal distances should be computed. This atlas should also have been used to define the test values.

#### `-q`: Test values

A file containing an edgewise vector of values to evaluate for distance-dependence. Often, these will be the QC-FC estimates produced by the `qcfc` utility.

#### `-o`: Output

The path where the overall correlation coefficient between distance and test values should be saved.

#### `-d`: Distance matrix

The path where the matrix of distances between each pair of nodes in the provided atlas (argument to `-a`) is saved.

#### `-f`: Save correlation plot

The path where the scatter plot of edgewise distance and test values will be saved. If `ggplot2` and `reshape2` are not installed, then the plot is automatically disabled.

#### `-i`: Intermediate output path

A path where `erodespare` stores temporary files. If your machine or file system has a designated space for temporary files (e.g., `/tmp`), then using this space can substantially improve I/O speed.
