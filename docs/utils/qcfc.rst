.. _qcfc:

QCFC
======

Quality control for functional connectivity.


``qcfc`` computes, for each edge in the connectome, the partial correlation (across subjects) of
motion with the strength of that edge, after controlling for the effects of any user-provided
covariates. ``qcfc`` is currently written as an R script (``utils/qcfc.R``). It requires as input a
sample matrix containing motion estimates for each subject

Output
------

The root output path, ``<output root>``, is specified as the argument to the ``-o`` option. Outputs
of ``qcfc`` include:

 * ``<output root>.txt``: A matrix containing the QC-FC correlation for each edge in the input
   matrix from the ``connectivity`` column provided to the ``-s`` argument.
 * ``<output root>_thr.txt``: (if ``-r`` is ``true``) The QC-FC matrix from above, thresholded to
   include only significant edges. This can be used to plot glass brain visualisations of
   significant edges, for instance using BrainNetViewer.
 * ``<output root>_absMedCor.txt``: (if ``-q`` is ``true``) The absolute median QC-FC correlation
   over all edges.
 * ``<output root>_nSigEdges.txt``, ``<out>_pctSigEdges.txt``: (if ``-q`` is ``true``) The number
   and percentage of edges with significant QC-FC correlations.
 * ``<output root>.svg``: (if ``-f`` is ``true``) A visualisation of the QC-FC distribution).


Input arguments
---------------

Example call from Docker:::

  docker run --rm -it \
    --entrypoint /xcpEngine/utils/qcfc.R \
    pennbbl/xcpEngine:latest \
    –c <cohort> \
    -o <output root> \
    [-s <multiple comparisons correction> \
     -t <significance threshold> \
     -n <confound> \
     -y <conformula>]

Optional arguments are denoted in square brackets (``[]``).

``-c``: Cohort
~~~~~~~~~~~~~~~~~~

The primary input to qcfc.R (``<cohort>``) should be a subject list that includes a separate column
for each subject identifier and two additional columns corresponding to subject movement (or
another scalar-valued quality control variable) and functional connectivity. Each row in the
subject list should correspond to a separate subject. Each column containing identifiers should
have a header beginning with the string ``id``, while 2 additional columns should have the headers
``motion`` and ``connectivity``. In each subject’s ``motion`` column, enter the subject’s mean
framewise displacement (or another scalar-valued quality control variable). In each subject’s
``connectivity`` column, enter the path to the subject’s connectivity matrix (or any vector of
values that may be impacted by subject motion). Save the subject list in ``.csv`` format. An
example subject list is provided here:::

  id0,id1,motion,connectivity
  ACC,001,0.0391,processedData/ACC_001_fc/connectome.txt
  ACC,002,0.0455,processedData/ACC_002_fc/connectome.txt
  ACC,003,0.0367,processedData/ACC_003_fc/connectome.txt
  DSQ,001,0.1532,processedData/DSQ_001_fc/connectome.txt
  CAT,001,0.0811,processedData/CAT_001_fc/connectome.txt

``-s``: Correction for multiple comparisons
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*Default value: ``fdr``*

The type of correction for multiple comparisons can be specified as ``fdr``, ``bonferroni``, or
``none``. When evaluating only a few subjects, it may be more diagnostically informative to disable
multiple comparisons correction (``-s none``).


``-t``: Alpha significance threshold
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*Default value: ``0.05``*

The maximal p-value threshold necessary to establish a QC-FC relationship as significant can be
specified as an argument to the ``-t`` option.

``-n`` and ``-y``: Confound matrix and formula
--------------------------------------------------

The values of any model covariates that motion effects might alias (such as age and sex) should be
included in another file containing the same subject identifiers as the subject list (argument to
``-s``). The file containing model covariates should be provided as an argument to the ``-n``
option, and the formula for the model should be provided as an argument to the ``-y`` option, with
any categorical variables specified as factors (see example below). (If the user wishes to obtain
only the direct correlation between motion and functional connectivity, then no formula or
covariates file is necessary.)

For example, to control for the participants’ age and sex when computing motion effects, prepare a
file containing the same identifiers and ``id`` column headers as the subject list (argument to
``-s``), with additional columns for each of the covariates to be considered. In the example below,
age is defined in months and sex is coded as a binary variable:::

  id0,id1,age,sex
  ACC,001,217,0
  ACC,002,238,1
  ACC,003,238,1
  DSQ,001,154,0
  CAT,001,176,1

If this file is saved as ``sample-covariates.csv``, then call qcfc.R as above, with the additional
argument to ``-n`` set to ``sample-covariates.csv`` and the argument to ``-y`` set to: ::

  age+factor(sex)

Note that sex, treated as a categorical variable in this toy example, is specified as a ``factor``.
If the data set contains repeated measures (e.g., multiple scans from the same subject), then the
subject identifier can be included in the model specification (argument to ``-y``) as a random
intercept:::

  age+factor(sex)+(1|id0)

``-o``: Output root
~~~~~~~~~~~~~~~~~~~~~~~

A prefix that points to a valid directory, where all outputs will be written after they are
computed.

``-d``: Data root path
~~~~~~~~~~~~~~~~~~~~~~~~~

It is sometimes desirable to define paths relative to some root directory instead of as absolute
paths in order to facilitate data sharing and reproduction of results. If the paths in the
``connectivity`` column of the subject list (argument to ``-s``) are defined in a relative manner,
the root path relative to which they are defined should be provided as the argument to the ``-d``
option.


``-r``: Save thresholded matrix
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*Default value: ``true``*

A logical-valued option indicating whether ``qcfc`` should save the QC-FC matrix thresholded to
include only significant edges. This matrix can, for instance, be used to visualise only
significant edges using a tool such as BrainNetViewer.

``-q``: Save QC-FC summary indices
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*Default value: ``true``*

A logical-valued option indicating whether ``qcfc`` should save indices that summarise the QC-FC
distribution. These indices include the absolute median correlation and the number and fraction of
significant QC-FC relationships.

``-f``: Save QC-FC distribution plot
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*Default value: ``true``*

A logical-valued option indicating whether ``qcfc`` should save a density plot of the QC-FC
distribution. If ``ggplot2`` and ``reshape2`` are not installed, then this option is automatically
disabled.
