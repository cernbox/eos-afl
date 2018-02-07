#!/bin/bash

usage () {
  echo "Usage: ./build [-r <registry> -i -b -p] [-h]"
  echo
  echo "   OPTIONAL: "
  echo "   -r <registry> define a docker registry to push to"
  echo "   -i compile with added instrumentation from afl-gcc"
  echo "   -b actually do a build"
  echo "   -p push to registry (-r must also be specified for -p to work)"
  echo
  echo "   -h help"
  echo
  exit 1
}

while getopts "r:ibph" opt; do
    case "$opt" in
        r) 
            if [ ! $REGISTRY ]; then
	        case "$OPTARG" in
                  */) REGISTRY=$OPTARG ;;
                  *)  REGISTRY=$OPTARG/ ;;
                esac
            else
                echo "ERROR: can't define multiple registries!"
                usage
            fi
	    ;;
        i) 
            INSTRUMENT=true
	    ;;
        b) 
            BUILD=true
	    ;;
        p) 
            PUSH=true
	    ;;
        h) 
            usage
	    ;;
    esac
done

BASE_NAME="eos-fuzz-base"
FUZZ_NAME="eos-fuzz"

if [ ! -z "$REGISTRY" ]; then
    echo "docker registry: ${REGISTRY}"
    BASE_NAME=${REGISTRY}${BASE_NAME}
    FUZZ_NAME=${REGISTRY}${FUZZ_NAME}
else
    if [[ "$PUSH" = "true" ]]; then
        echo "Error: yeah nah, you didn't define a registry to push to"
        usage
    fi
fi

if [[ "$BUILD" = "true" ]]; then
    if [[ "$INSTRUMENT" = "true" ]]; then
        echo "building container with afl-gcc-compiled eos & xrootd"
	BASE_NAME=${BASE_NAME}:afl
	FUZZ_NAME=${FUZZ_NAME}:afl
	sed s:AFL_COMPILE::g Dockerbase.tmp > Dockerbase
	sed s:AFL_COMPILE::g Dockerfile.tmp > Dockerfile
    else
        echo "building container with default eos & xrootd"
        BASE_NAME=${BASE_NAME}:default
        FUZZ_NAME=${FUZZ_NAME}:default
	sed s:AFL_COMPILE:\#:g Dockerbase.tmp > Dockerbase
	sed s:AFL_COMPILE:\#:g Dockerfile.tmp > Dockerfile
    fi

    sed -i "s|FUZZ_BASE_IMAGE|${BASE_NAME}|g" Dockerfile
    docker build -f Dockerbase -t ${BASE_NAME} . && \
    docker build -f Dockerfile -t ${FUZZ_NAME} . && \
    rm Dockerbase Dockerfile
fi

if [[ "$PUSH" = "true" ]]; then
    echo "pushing image ${FUZZ_NAME}"
    docker push ${FUZZ_NAME}
fi
