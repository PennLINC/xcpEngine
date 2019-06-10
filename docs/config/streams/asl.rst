.. _asl:

Arterial spin labeling streams
================================
Arterial spin labeling (ASL) provides non-invasive quantification of cerebral blood flow (CBF). 
The `xcpEnigne` includes 4 standard modules for the  quantification of the CBF. The modules are: 
1. `CBF`: The standard quantification of CBF that based on the relatively basic model ` Buxton et al 1998 <https://www.ncbi.nlm.nih.gov/pubmed/9727941>`_. 
2. `BASIL` : `BASIL<https://asl-docs.readthedocs.io/en/latest/>`_ uses Bayesian inference method for the kinetic model inversion and was origibally debvloped for multidelay data. 
BASIL provides vearious advantages inckluding spatial regularization of the estimated perfusion image and correction of partial volume effects. It is part of `FSL <https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BASIL>`_ and 
can also be used as standalone. 
3. `SCORE`:  SCORE (Structural Correlation based Outlier Rejection) developed by `Dolui et al 2017<https://www.ncbi.nlm.nih.gov/pubmed/27570967>`_. SCORE algrorithms detects and discards 
individual CBF volumes in ASL timesieries that contaminate mean the CBF maps. It requires prior computaion of CBF (1) timesieries. 
4. `SCRUB`: SCRUB( Structural Correlation with RobUst Bayesian) was also debvloped by `Dolui et al 2016<http://archive.ismrm.org/2016/2880.html>`_. SCRUB, like BASIL, uses robust Bayesian estimation of 
CBF by removing tthe white noise as opposed to outlier rejection. The SCRUB is implmeented in xcpEnigne  to run SCORE to first discard ouliers CBF volumes contributing to the artifacts. 

Each module can be run seperately and all modules can be run together but `SCORE` and `SCRUB` require CBF timesieries ( one of the output of `CBF` module).

Available modules
------------------

 * :ref:`cbf`
 * :ref:`basil`
 * :ref:`score`
 * :ref:`scrub`
 