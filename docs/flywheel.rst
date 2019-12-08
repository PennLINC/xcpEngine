
xcpEngine on Flywheel
===================================
The xcpEngine can be run on `flywheel <https://upenn.flywheel.io>`_. The procedure is the same as runnning it on computers/clusters. 


The `design file <https://xcpengine.readthedocs.io/config/design.html>`_ is compulsory for any analysis. 
Preprocessing of BOLD data require prior preprocessing with `FMRIPREP`. The FMRIPREP output directory needs to be supplied 
as shown below. 

.. figure:: _static/xcpenginelayout.png 
    
    xcpEngine input layout  on Flywheel
-----------------------------------------

The cohort file will be created base on the FMRIPREP output and/or  img.  The `img` is input  directory for asl and structural image. The processing of ASL requires  
processed anatomical image from FRMIPREP (fmriprepdir) or structural processing output (antsct). The  `m0` is the M0 directory for CBF calibration if present. 

   Task-activation analysis
-----------------------------

Running task-activation (FSL FEAT) analysis on flywheel with xcpEngine requires event files like FSL. The evnets an be in any format accpetable by the 
FSL FEAT. The contrasts and corresponding weights are organized as shown in `task.json` shown below.::   

           {
              "eventname":["0back","1back","2back","inst"], 
              "contrast" :{ "0back":          [1,0,0,0], 
                            "1back":          [0,1,0,0],
                            "2back":          [0,0,1,0], 
                            "2backvs0back":   [-1,0,1,0],
                            "1backvs0back":   [-1,1,0,0] }
            }

The above shown the event names ( "0back","1back","2back","inst") and  the contrast with corresponding weights. 
The `task.json` is zipped  with all the event files::
   0back.txt
   1back.txt 
   2back.txt
   inst.txt 
   task.json 

The zipped file is attach to `taskfile` in the inout directory of xcpengine gear in flywheel (check figure above) 

The length of the  weight must be equal to the number of events as shown above.