.. _streams:

Processing streams
===================

Neuroimage processing refers collectively to the set of strategies used to convert the "raw" images
collected from the scanner into appropriate inputs to group-level statistical analyses. A
*processing stream* is the specific set of routines that are selected to extract a desired modality
of analytic data from a neuroimage.

In the XCP system, a standard set of processing streams is available for each supported imaging
modality. Each processing stream is parameterized by a design file.
Detailed information about standard implementations of multimodal processing streams is available
at the links below, organized by imaging modality.

.. toctree::
   :maxdepth: 1

   anat
   fc
   asl
