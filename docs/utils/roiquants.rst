.. _roiquants:

ROI Quantification
===================

Region of Interest Quantification.


``roiquant`` uses atlas provided in design file to compute the  regional derivative values especially for `reho` 
and `alff` outputs.  The users can also used customed atlases to generate region values from the output.

The customed atlas and the input image such as `rehoZ` must  have the same dimension and orientation. 
This can be done with `${XCPEDIR}/utils/quantifyAtlas` :: 
  
   ${XCPEDIR}/utils/quantifyAtlas  \
      -v ``inputfile``  \  # this is input image 3D
      -s  mean \ # the statistics, the defualt is the mean of each roi in atlas 
      -a ``atlas``  \ # the atlas in 3D 
      -n ``atlas_name`` \ # atlas name : option 
      -p  id1,id2 \ # subject idenfiers  : option 
      -r  ``region_names`` \ # name of regions in atlas : option
      -o  ``output_path.txt`` 

The output will conist of headear with ids and region names  or numbers with the correpping values atlas rois as show below::

     id1,id2, reho_mean_region1,reho_mean_region2,...
     ses-01,sub-1, 0.3456,0.7894,...


Similarly, users can extract time series from BOLD image with the customized atlas. This is similar to the output in `fcon` module. 
It is called::

   $XCPEDIR/utils/roi2ts.R   \
         -i   $input    \  # the 4D bold image 
         -r   $atlas       \ # the atlas in the same orientation as bold
         -l   $atlas_label \ # atlas region label  but not compulsory
         >>    $output.txt   # output file
   
