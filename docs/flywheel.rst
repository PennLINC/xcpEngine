
``Running xcpEngine on Flywheel``
===================================
The xcpEngine can be run on `flywheel <https://upenn.flywheel.io>`. The same procedure is as runnning on computers/clusters. 

.. figure:: _static/xcpengineflywheel.png
    :align: center

    xcpEngine on Flywheel

The `design file < https://xcpengine.readthedocs.io/config/design.html > ` is compulsory for any analysis. 
Preprocessing of BOLD data required prior preprocessing with `FMRIPREP`. The FMRIPREP output directory need to be supplied 
as shown below. 

.. figure:: _static/xcpenginelayout.png 
    :align: center

    xcpEngine input layout  on Flywheel



The cohortfile will be created based on the FMRIPREP output. The `img` inout directory for CBF. The processing of CBF require the 
anatomical preprocessing from FRMIPREP. The  `m0` is the M0 directory for CBF claibration if present. The `struct` is the directory for 
T1W image for sturcural preprocessing. 

After successful run, the `xcpEngine` zip the results and cohortfile to analyses directory of the subject as hsown below;

.. figure:: _static/xcpengineoutput.png 
    :align: left

    xcpEngine output layout  on Flywheel