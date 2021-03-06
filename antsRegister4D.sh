#!/bin/sh
set -e

#Michael Hart, University of Cambridge, 13 April 2016 (c)

#define directories

codedir=${HOME}/bin
basedir="$(pwd -P)"

#make usage function

usage()
{
cat<<EOF
usage: $0 options

===========================================================================

antsRegister4D.sh

(c) Michael Hart, University of Cambridge, 2016

Warps a 4D epi to standard space

Example:

antsRegister4D.sh -f epi.nii.gz -w warp.nii.gz -r affine.mat

Options:

-h  show this help
-f  functional (epi)
-w  warp (contactenated transform) from structural-to-standard
-r  rigid transform from epi-to-structural
-t  standard space template e.g. MNI
-o  overwrite
-v  verbose

Version:    1.1

History:    no amendments

============================================================================

EOF
}


###################
# Standard checks #
###################


#initialise options

functional=
structural=
warp=
affine=
template=

while getopts "hf:w:r:t:ov" OPTION
do
    case $OPTION in
    h)
        usage
        exit 1
        ;;
    f)
        functional=$OPTARG
        ;;
    w)
        warp=$OPTARG
        ;;
    r)
        affine=$OPTARG
        ;;
    t)
        template=$OPTARG
        ;;
    o)
	overwrite=1
	;;
    v)
	verbose=1
	;;	
    ?)
        usage
        exit
        ;;
    esac
done

#set verbose option

if [ "$verbose" == 1 ]
then
    set -x verbose
fi

#check usage

if [[ -z $functional ]] || [[ -z $warp ]] || [[ -z $affine ]] 
then
    echo "usage incorrect"
    usage
    exit 1
fi

echo "options ok"

# final check of files

echo "Checking functional and structural data"

functional=${basedir}/${functional}

if [ $(imtest $functional) == 1 ];
then
    echo "$functional dataset ok"
else
    echo "Cannot locate file $functional. Please ensure the $functional dataset is in this directory"
    exit 1
fi

warp=${basedir}/${warp}

if [ $(imtest $warp) == 1 ];
then
    echo "$warp dataset ok"
else
    echo "Cannot locate file $warp. Please ensure the $warp dataset is in this directory"
    exit 1
fi

affine=${basedir}/${affine}

if [ -f $affine ];
then
    echo "$affine dataset ok"
else
    echo "Cannot locate file $affine. Please ensure the $affine dataset is in this directory"
    exit 1
fi

echo "files ok"

if [ $(imtest $template) == 1 ];
then
    echo "$template dataset ok"
    template=${basedir}/${template}
else
    template=${HOME}/ANTS/ANTS_templates/MNI/MNI152_T1_2mm_brain.nii.gz
    echo "No template supplied - using MNI brain"
fi

#make output directory

if [ ! -d ${basedir}/A4D ];
then
    echo "making output directory"
    mkdir ${basedir}/A4D
else
    echo "output directory already exists"
    if [ "$overwrite" == 1 ]
    then
        echo "overwriting output directory"
        mkdir -p ${basedir}/A4D
    else
        echo "no overwrite permission to make new output directory"
    exit 1
    fi
fi

outdir=${basedir}/A4D

#make temporary directory

tempdir="$(mktemp -t -d temp.XXXXXXXX)"

cd "${tempdir}"

#start logfile

touch AER_logfile.txt
log=AER_logfile.txt

echo $(date) >> ${log}
echo "${@}" >> ${log}


##################
# Main programme #
##################


function A4DR(){

    #1. generate number of volumes and time between them (aka TR)

    hislice=`PrintHeader $functional | grep Dimens | cut -d ',' -f 4 | cut -d ']' -f 1`
    tr=`PrintHeader $functional | grep "Voxel Spac" | cut -d ',' -f 4 | cut -d ']' -f 1`

    #2. concatentate transforms
    #start farthest away from image
    #use inverse transforms for mprage-to-MNI (opposite of ATR) and in opposite order
    #finally add epi-to-mprage affine.mat

    antsApplyTransforms \
    -d 3 \
    -t $warp \
    -t $affine \
    -o [diffCollapsedWarp.nii.gz, 1] \
    -r $template

    #3. multiply transforms

    echo "replicating concatenated transforms"

    ImageMath 3 \
    diff4DCollapsedWarp.nii.gz \
    ReplicateDisplacement \
    diffCollapsedWarp.nii.gz \
    $hislice $tr 0 #

    #4. multiply template

    echo "replicating template"

    ImageMath 3 \
    MNI_replicated.nii.gz \
    ReplicateImage \
    $template \
    $hislice $tr 0

    #5. apply tranforms

    echo "applying transforms: epi-to-MNI"

    antsApplyTransforms -d 4 \
    -o epi2template.nii.gz \
    -t diff4DCollapsedWarp.nii.gz \
    -r MNI_replicated.nii.gz \
    -i $functional

}

#call function

A4DR

#check results
echo "now making some summary pictures"

slices_summary epi2template.nii.gz 4 $template pictures.sum
cd pictures.sum
nImages=$(ls -l | wc -l)
nImages=$((( nImages - 1 )))
nPictures=$(for ((i=0; i<${nImages}; i++)); do printf "${i} "; done)
cd ..
slices_summary pictures.sum single_picture.png $nPictures

#cleanup
cp -fpR . "${outdir}"
cd "${outdir}"
rm -Rf "${tempdir}" MNI_replicated.nii.gz diff4DCollapsedWarp.nii.gz

#close up
echo "all done" >> ${log}
echo $(date) >> ${log}
