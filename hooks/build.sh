#!/bin/bash

TAG="hseeberger/scala-sbt:${TAG}"

set -x
docker build $DOCKER_CONTEXT \
    --no-cache \
    -t "$TAG" \
    --build-arg BASE_IMAGE_TAG=$BASE_IMAGE_TAG \
    --build-arg SBT_VERSION=$SBT_VERSION \
    --build-arg SCALA_VERSION=$SCALA_VERSION

