#!/bin/sh

# uberAnts.sh
#
# reguires following files in directory:
#
# mprage.nii.gz, tumour_mask.nii.gz, epi123_medn.nii.gz, melodic_IC.nii.gz
#
# Created by Michael Hart on 27/05/2016.

touch uberAntsLog.txt
log=uberAntsLog.txt

echo $(date) >> $log
echo "time to start uberAnts" >> $log

######################################################################

#1. Brain extraction of structural

echo "" >> $log
echo $(date) >> $log
echo "doing antsBrains" >> $log

antsBrains.sh -s mprage.nii.gz

echo $(date) >> $log
echo "all done with antsBrains" >> $log
echo "" >> $log

######################################################################

#2. Structural to standard space registration

echo $(date) >> $log
echo "doing antsTumourReg" >> $log

antsTumourReg.sh -s ABE/BrainExtractionBrain.nii.gz -m tumour_mask.nii.gz
#brain from antsBrains.sh

echo $(date) >> $log
echo "all done with antsTumourReg" >> $log
echo "" >> $log

######################################################################

#3. Functional to structural registration

echo $(date) >> $log
echo "doing antsEpiReg" >> $log

antsEpiReg.sh -f epi123_medn.nii.gz -s ABE/BrainExtractionBrain.nii.gz
#brain from antsBrains.sh

echo $(date) >> $log
echo "all done with antsEpiReg" >> $log
echo "" >> $log

######################################################################

#4. Functional to standard registration

echo $(date) >> $log
echo "doing antsRegister4D" >> $log

antsRegister4D.sh -f melodic_IC.nii.gz -w ATR/structural2standard.nii.gz -r AER/affine0GenericAffine.mat
#transforms from antsEpiReg.sh & antsTumourReg.sh

echo $(date) >> $log
echo "all done with antsRegister4D" >> $log
echo "" >> $log

######################################################################

#5. Cortical thickness pipeline

echo $(date) >> $log
echo "doing antsTumourCT"

antsTumourCT.sh -s mprage.nii.gz -m ATR/tumour_mask_MNI.nii.gz
#tumour mask from antsTumourReg.sh

echo $(date) >> $log
echo "all done with antsTumourCT" >> $log
echo "" >> $log

######################################################################

#6. Parcellation
echo $(date) >> $log
echo "doing antsParcellates"

antsParcellates.sh -f ffd_clean.nii.gz -w ATR/standard2structural.nii.gz -r AER/affine0GenericAffine.mat
#uses default parcellation

antsParcellates.sh -f epi123_medn.nii.gz -w ATR/standard2structural.nii.gz -r AER/affine0GenericAffine.mat -p  ~/templates/rafa/rafa251.nii.gz

antsParcellates.sh -f epi123_medn.nii.gz -w ATR/standard2structural.nii.gz -r AER/affine0GenericAffine.mat -p ~/templates/cluster/cluster250.nii.gz

echo $(date) >> $log
echo "all done with antsParcellates" >> $log
echo "" >> $log

######################################################################

#7. Close up

echo "all done with uberAnts" >> $log
echo $(date) >> $log
