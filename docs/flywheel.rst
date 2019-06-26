
xcpEngine on Flywheel
===================================
The xcpEngine can be run on `flywheel <https://upenn.flywheel.io>`_. The procedure is the same as runnning it on computers/clusters. 
   
    xcpEngine on Flywheel

The `design file <https://xcpengine.readthedocs.io/config/design.html>`_ is compulsory for any analysis. 
Preprocessing of BOLD data require prior preprocessing with `FMRIPREP`. The FMRIPREP output directory needs to be supplied 
as shown below. 

.. figure:: _static/xcpenginelayout.png 
    
    xcpEngine input layout  on Flywheel
-----------------------------------------


The cohort file will be created base on the FMRIPREP output and/or  img.  The `img` is input  directory for asl and structural image. The processing of ASL requires the 
anatomical preprocessing from FRMIPREP (fmriprepdir) or structural processing output (antsct). The  `m0` is the M0 directory for CBF calibration if present. 

   Task-activation and task-regression 
-----------------------------------------

Running task activation on flywheel with xcpEngine requires event file (all events in one file with header, file.txt) and contrast in json file  with corresponding weights. 
For example, eyes-open and eyes-close experiment events can be combine as follow, `event.txt` ::
           eyesopen   eyesclose
              0          1
              0          1
              1          0
              1          0
              1          0
              ..         ..
              1          0

The task contrast (file.json.::
           { 
              "eyeopen":[1,0],
              "eyeclose":[0,1],
              "openandclose":[1,1],
              "eyeopen-eyesclose":[1,-1],
              "eyelose-eyeopen":[-1,1]
              }

The length of weight must be equal to number of events.