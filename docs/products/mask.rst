# `mask`

_Brain boundary estimate._

A binary-valued voxelwise NIfTI derivative of an analyte image. Each voxel in `mask` is assigned the value 1 if it is classified as brain tissue and 0 otherwise. `mask` can be multiplied with any other image in the same space to produce a brain-extracted or brain-only version of that other image.
