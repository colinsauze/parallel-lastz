#!/bin/sh

echo "example script to run lastz and chaining on two genomes in 2bit files"
echo "adjust this script for your local example, you have a couple of choices"
echo "for parameter sets.  You will need a parasol cluster computer system"
echo "to run the large number of lastz instances."
echo "requires companion script constructLiftFile.pl and"
echo "partitionSequence.pl"
echo 
echo "The point is to illustrate the steps of:"
echo "1. partitioning the two genomes into:"
echo "   a. 10,000,000 overlapping 10,000 chunks for the target sequence"
echo "   b. 20,000,000 no overlap chunks for the query sequence"
echo "2. setup cluster run target.list query.list lastz run script"
echo "3. chaining the psl results from the lastz procedure"

#exit 255

# typical axtChain and lastz parameter sets:
export chainNear="-minScore=5000 -linearGap=medium"
export chainMedium="-minScore=3000 -linearGap=medium"
export chainFar="-minScore=1000 -linearGap=loose"
export lastzMedium="B=0 C=0 E=30 H=0 K=3000 L=3000 M=50 O=400 T=1 Y=9400"
export lastzFar="B=0 C=0 E=30 H=2000 K=2200 L=6000 M=50 O=400 Q=/scratch/data/blastz/HoxD55.q T=2 Y=3400"

# select one of three different parameter sets
# Near == genomes close to each other
# Medium == genomes at middle distance from each other
# Far == genomes distant from each other

hostname
date

export lastzNear="E=30:H=2000:K=3000:L=2200:M=50:O=400:Q=$WRKDIR/conf/matrix.q"
export chainParams="$chainMedium"
export lastzParams="$lastzNear"

#  WRKDIR is where your 2bit files are and where you want this to work
export WRKDIR=$1
#sid - Dir structure WRKDIR->QDIR->TDIR
export TDIR=$2
#sid - This is the name of the TARGET and QUERY
export TNAME=$3
export QNAME=$4
export DBDIR=$5
export target_species=$6
export species=$7
export BINDIR=$WRKDIR/bin

#sid - this is the directory for the genmoes and query
export TARGET=${DBDIR}/TARGET-Genomes/$target_species/${TNAME}.2bit
export QUERY=${DBDIR}/Genomes/${QNAME}.2bit

#*******************************************************************************************
# TWO BIT INFO 
# sid - the two bit info is a package that is available in path and is invoked here


#the output of this is the TARGET.chrom.sizes and QUERY.chrom.sizes

#*******************************************************************************************

/home/${USER}/PARALLEL_LASTZ/${species}/bin/UCSC_Genome_Browser/twoBitInfo $TARGET stdout | sort -k2nr > ${TDIR}/${TNAME}.chrom.sizes

rm -fr ${TDIR}/${TNAME}PartList ${TDIR}/${TNAME}.part.list 2> /dev/null
echo -n "creating the directory now ${TNAME}PartList"
mkdir ${TDIR}/${TNAME}PartList 2> /dev/null

# sid - Done with Target Partlist creation, on to query now

 /home/${USER}/PARALLEL_LASTZ/${species}/bin/UCSC_Genome_Browser/twoBitInfo $QUERY stdout | sort -k2nr > ${TDIR}/${QNAME}.chrom.sizes
rm -fr ${TDIR}/${QNAME}PartList ${TDIR}/${QNAME}.part.list 2> /dev/null
echo -n "creating the directory now ${TDIR}/${QNAME}PartList"
mkdir ${TDIR}/${QNAME}PartList 2> /dev/null

#********************************************************************************************
#sid- End of twoBitInfo Stage

#sid - The PartList generation is done, now we have to look at the list files created in that directory and generate part.list files which is a concatenation of all the files present

#********************************************************************************************




#sid if the part list is not of zero size then do this
#this part.list is expected to be generated by the below command

if [ ! -s ${TDIR}/${TNAME}.part.list ]; then
	echo -n  "-DEBUG- partitionSequence.pl 80000000 10000 ${TARGET} ${TNAME}.chrom.sizes 1 -lstDir ${TNAME}PartList > ${TDIR}/${TNAME}.part.list"

#TODO : Take out this magic numbers and put this in a variable 
	${BINDIR}/partitionSequence.pl 200000000 10000 ${TARGET} ${TDIR}/${TNAME}.chrom.sizes 1 -lstDir ${TDIR}/${TNAME}PartList > ${TDIR}/${TNAME}.part.list
fi

#same as above but for query

if [ ! -s ${TDIR}/${QNAME}.part.list ]; then
	${BINDIR}/partitionSequence.pl 200000000 0 ${QUERY} ${TDIR}/${QNAME}.chrom.sizes 1 -lstDir ${TDIR}/${QNAME}PartList > ${TDIR}/${QNAME}.part.list
fi

#you dont like PartList, take that out and put that in the file target.list

grep -v PartList ${TDIR}/${TNAME}.part.list > ${TDIR}/target.list

#loop through the directory and look at all the *.lst files one by one and put that in one file called target.list
for F in ${TDIR}/${TNAME}PartList/*.lst
do
    cat ${F}
done >> ${TDIR}/target.list



#same as above for query
grep -v PartList ${TDIR}/${QNAME}.part.list > ${TDIR}/query.list
#This directory need not be created with *.lst this is optional if $size > $chomp + $lap
for F in ${TDIR}/${QNAME}PartList/*.lst
do
    cat ${F}
done >> ${TDIR}/query.list

#**************** Done with part.list creation **********************************************






#********************************************
# Stage 2 of the script, use the above files to feed constructLiftFile.pl
#********************************************

echo "Done with generating the list files, into construct stage now to output target.lift and query.lift\n"

perl ${BINDIR}/constructLiftFile.pl ${TDIR}/${TNAME}.chrom.sizes ${TDIR}/target.list > ${TDIR}/target.lift
perl ${BINDIR}/constructLiftFile.pl ${TDIR}/${QNAME}.chrom.sizes ${TDIR}/query.list > ${TDIR}/query.lift

echo "Lift files generated\n"

echo "in runLast - species - ${species} ; #perl ${BINDIR}/heredoc.pl $TDIR $TNAME $QNAME $chainParams $lastzParams $target_species $species"

perl ${BINDIR}/heredoc.pl $TDIR $TNAME $QNAME "$chainParams" "$lastzParams" $target_species $species
exit 0