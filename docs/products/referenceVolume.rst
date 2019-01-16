# `referenceVolume` and `referenceVolumeBrain`

_Single-volume reference image._

A voxelwise NIfTI derivative of a 4D analyte image. When a 4D image is acquired, each 3D volume of the image is acquired separately, and anatomical landmarks across these volumes may not always be aligned, for instance due to subject head movement. To ensure consistent placement of anatomical landmarks, the pipeline system uses FSL's MCFLIRT to align all volumes; `referenceVolume` is a NIfTI image that is used as the target of the alignment procedure. That is, anatomical landmarks across all volumes of the 4D image are aligned to their counterparts in `referenceVolume`.
