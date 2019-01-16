# `meanIntensity` and `meanIntensityBrain`

_Voxelwise map of average intensity over all volumes._

A voxelwise NIfTI derivative of a 4D analyte image. The value of each voxel in `meanIntensity` is equal to the average intensity of the equivalent voxel across all volumes of the 4D analyte. `meanIntensityBrain` is `meanIntensity` with all non-brain voxels set to a value of 0. `meanIntensity` is equivalent to `mean_func` in FSL.
