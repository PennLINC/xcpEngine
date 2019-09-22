.. _asl:

Arterial spin labeling streams
================================
Arterial spin labeling (ASL) provides non-invasive quantification of cerebral blood flow (CBF).:: 

The `xcpEngine` includes 3 standard modules for the  quantification of the CBF. The modules are.:


1. `CBF`: The standard quantification of CBF that base on the relatively basic model `Buxton et al 1998 <https://www.ncbi.nlm.nih.gov/pubmed/9727941>`_ 

2.  `BASIL`:  The `BASIL <https://asl-docs.readthedocs.io/en/latest/>`_  uses Bayesian inference method for the kinetic model inversion and was originially developed for multidelay data. 
BASIL provides various advantages including spatial regularization of the estimated perfusion image and correction of partial volume effects. It is part of `FSL <https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BASIL>`_ and 
can also be run as standalone. 

3. `SCORESCRUB`:  SCORE (Structural Correlation based Outlier Rejection) developed by  `Dolui et al 2017 <https://www.ncbi.nlm.nih.gov/pubmed/27570967>`_ .  SCORE algrorithm detects and discards 
individual CBF volumes of  ASL timeseries that contaminate the mean CBF maps. It requires prior computaion of CBF (1) timesseries. 
`SCRUB`: SCRUB( Structural Correlation with RobUst Bayesian) was also developed by `Dolui et al 2016 <http://archive.ismrm.org/2016/2880.html>`_. SCRUB, like BASIL, uses robust Bayesian estimation of 
CBF by removing the white noise as opposed to outlier rejection. The SCRUB is implemented in xcpEnigne but use SCORE to first discard outlier CBF volumes. 

Each module can be run seperately and all modules can be run together but `SCORESCRUB` require CBF timeseries ( one of the outputs of `CBF` module).

Available modules
------------------

 * :ref:`cbf`
 * :ref:`basil`
 * :ref:`scorescrub`

 