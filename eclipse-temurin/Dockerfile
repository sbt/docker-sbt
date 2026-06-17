#
# Scala and sbt Dockerfile
#
# https://github.com/sbt/docker-sbt
#

# Pull base image
ARG BASE_IMAGE_TAG
FROM eclipse-temurin:${BASE_IMAGE_TAG:-11.0.16.1_1-jdk}

# Env variables
# Default only applies when the build arg is unset (manual builds). The build
# workflow passes SCALA_VERSION explicitly: a value for fat images, an empty
# string for light images. Using an ARG default (not ${VAR:-...}, which also
# fires on an empty value) keeps an explicit empty arg empty, so light images
# skip the Scala warm-up below.
ARG SCALA_VERSION=2.13.10
ENV SCALA_VERSION=${SCALA_VERSION}
ARG SBT_VERSION
ENV SBT_VERSION=${SBT_VERSION:-1.6.2}
ARG USER_ID
ENV USER_ID=${USER_ID:-1001}
ARG GROUP_ID
ENV GROUP_ID=${GROUP_ID:-1001}

# Install dependencies
# curl for downloading sbt and scala
# git and rpm for sbt-native-packager (see https://github.com/sbt/docker-sbt/pull/114)
RUN \
  apt-get update && \
  apt-get install -y curl git rpm && \
  rm -rf /var/lib/apt/lists/*

# Install sbt
RUN \
  curl -fsL --show-error "https://github.com/sbt/sbt/releases/download/v$SBT_VERSION/sbt-$SBT_VERSION.tgz" | tar xfz - -C /usr/share && \
  chown -R root:root /usr/share/sbt && \
  chmod -R 755 /usr/share/sbt && \
  ln -s /usr/share/sbt/bin/sbt /usr/local/bin/sbt

# Symlink java to have it available on sbtuser's PATH
RUN ln -s /opt/java/openjdk/bin/java /usr/local/bin/java

# Add and use user sbtuser
RUN groupadd --gid $GROUP_ID sbtuser && useradd -m --gid $GROUP_ID --uid $USER_ID sbtuser --shell /bin/bash
ENV HOME=/home/sbtuser
# Allow running the image as an arbitrary uid (not only sbtuser): own sbtuser's
# home by the root group (gid 0, which `docker run -u <uid>` joins by default)
# and set the setgid bit, so files written by the warm cache below inherit gid 0;
# with `umask 0002` there they are created group-writable (no recursive chmod,
# which would copy the whole cache into a new layer).
RUN mkdir -p /home/sbtuser && chown sbtuser:0 /home/sbtuser && chmod 2775 /home/sbtuser
USER sbtuser

# Switch working directory
WORKDIR /home/sbtuser

# Prepare sbt. For fat images (a Scala version is set) compile a tiny project so
# the Scala compiler + bridge are cached. Light images pass an empty SCALA_VERSION:
# they ship sbt pre-installed but unwarmed (the user's project/build.properties
# picks the sbt version at runtime anyway), so we only create ~/.sbt and ~/.cache,
# which the root symlinks below point at. The dirs must exist or those symlinks
# dangle and `docker run ... sbt` fails as root in the launcher (see #401).
RUN \
  umask 0002 && \
  if [ -n "${SCALA_VERSION}" ]; then \
    mkdir -p project && \
    echo "scalaVersion := \"${SCALA_VERSION}\"" > build.sbt && \
    echo "sbt.version=${SBT_VERSION}" > project/build.properties && \
    echo "// force sbt compiler-bridge download" > project/Dependencies.scala && \
    echo "case object Temp" > Temp.scala && \
    sbt compile && \
    rm -r project && rm build.sbt && rm Temp.scala && rm -r target ; \
  else \
    mkdir -p .sbt .cache ; \
  fi

# Link everything into root as well
# This allows users of this container to choose, whether they want to run the container as sbtuser (non-root) or as root
USER root
RUN \
  rm -rf /tmp/..?* /tmp/.[!.]* * && \
  if [ -d "/home/sbtuser/.cache" ]; then ln -s /home/sbtuser/.cache /root/.cache; fi && \
  if [ -d "/home/sbtuser/.sbt" ]; then ln -s /home/sbtuser/.sbt /root/.sbt; fi && \
  if [ -d "/home/sbtuser/.ivy2" ]; then ln -s /home/sbtuser/.ivy2 /root/.ivy2; fi

# Switch working directory back to root
## Users wanting to use this container as non-root should combine the two following arguments
## -u sbtuser
## -w /home/sbtuser
WORKDIR /root

CMD ["sbt"]
