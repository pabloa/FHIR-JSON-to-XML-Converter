#!/bin/sh -f

# This command line script will download the current edition of the FHIR Schema into ../schema
# It will then apply an XSLT Script to convert the Schema to the conversion JavaScript in ../dist
#
# It is a port from build.cmd, although the flags are somewhat different and its
# workings a bit more automagic.
# 
# It downloads the schemas and processes them only if they are changed or --force is specified,
# aka it partially reinvents make. :-)

set -e  # exit on any untested failure status

run_dir=`pwd`
source_dir=`dirname "$(readlink -f $0)"`
cd "$source_dir"

force=0
verbose=0

while [ $# -gt 0 ]; do
    case "$1" in
	-f | --force)
	    force=1
	    shift
	    ;;
	-v | --verbose)
	    verbose=1
	    shift
	    ;;
	-vv | --verboser)
	    verbose=1
	    set -x
	    shift
	    ;;
	*)
	    echo "usage: $0 [-f | --force | -v | --verbose | -vv | -verboser]"
	    exit
	    ;;
    esac
done
	
# Create the schema folder if it is not present
if [ ! -e ../schema ]; then
    mkdir ../schema 2>/dev/null
fi

# Possibly get the Schemas from hl7.org...
fetched=0
if [ $force -eq 1 ]; then
    if [ $verbose -eq 1 ]; then
	echo "forcing fetch of fhir-all-xsd.zip from hl7.org to $PWD/../schema/..."
    fi

    curl -o ../schema/fhir-all-xsd.zip http://www.hl7.org/fhir/fhir-all-xsd.zip
    fetched=1
elif [ -e ../schema/fhir-all-xsd.zip ]; then
    if [ $verbose -eq 1 ]; then
	echo "fetching fhir-all-xsd.zip from hl7.org to $PWD/../schema/ iff our copy is out of date..."
    fi

    # already exists
    old_date=`stat -c %Y ../schema/fhir-all-xsd.zip`
    curl -o ../schema/fhir-all-xsd.zip --time-cond ../schema/fhir-all-xsd.zip http://www.hl7.org/fhir/fhir-all-xsd.zip
    if [ `stat -c %Y ../schema/fhir-all-xsd.zip` -ne $old_date ]; then
	fetched=1
    fi
else
    # doesn't already exist
    if [ $verbose -eq 1 ]; then
	echo "fetching fhir-all-xsd.zip from hl7.org to $PWD/../schema/..."
    fi

    curl -o ../schema/fhir-all-xsd.zip http://www.hl7.org/fhir/fhir-all-xsd.zip
    fetched=1
fi

if [ $verbose -eq 1 -a $fetched -eq 1 ]; then
    echo "fetched fhir-all-xsd.zip from hl7.org to $PWD/../schema/"
fi

if [ $force -eq 1 -o $fetched -eq 1 -o ! -e ../dist/fhir-convert.js -o ! -e ../schema/fhir-single.xsd ]; then
    # Extract fhir-single.xsd
    cd ../schema
    if [ $verbose -eq 1 ]; then
	echo "extracting $PWD/fhir-single.xsd from zipfile..."
    fi
    jar xf fhir-all-xsd.zip fhir-single.xsd

    cd "$source_dir"/..

    # Create the script
    if [ $verbose -eq 1 ]; then
	echo "creating $PWD/dist/fhir-convert.js from schemas..."
    fi
    java -cp /home/builder/idea-IU-181.5540.7/plugins/xslt-debugger/lib/rt/xalan.jar org.apache.xalan.xslt.Process -IN schema/fhir-single.xsd -XSL src/processFHIRSchema.xsl -OUT dist/fhir-convert.js
else
    echo "skipping rebuild of $PWD/dist/fhir-convert.js because everything was up to date and --force wasn't specified"    
fi


# Return to the launch directory
cd "$run_dir"
