# Use a multi-stage build to reduce the size of the final image
# The builder will install curl, bc and ca-certificates which are needed to install sbt.
# The final image will only contain bash, git, rpm and sbt.

ARG BASE_IMAGE_TAG
FROM eclipse-temurin:${BASE_IMAGE_TAG:-21.0.2_13-jdk-alpine} AS builder

ARG SCALA_VERSION=3.4.0
ARG SBT_VERSION=1.10.7
ARG USER_ID=1001
ARG GROUP_ID=1001

# Install dependencies
RUN apk add wget ca-certificates bash curl bc

# Update certificates, still needed?
RUN update-ca-certificates

# Install sbt
RUN \
    curl -fsL --show-error https://github.com/sbt/sbt/releases/download/v$SBT_VERSION/sbt-$SBT_VERSION.tgz | tar xfz - -C /usr/local && \
    ln -s /usr/local/sbt/bin/* /usr/local/bin/ && \
    sbt --script-version

# Start a new stage for the final image
FROM eclipse-temurin:${BASE_IMAGE_TAG:-21.0.2_13-jdk-alpine}

ARG SCALA_VERSION=3.4.0
ARG SBT_VERSION=1.9.9
ARG USER_ID=1001
ARG GROUP_ID=1001

RUN apk add --no-cache bash git rpm

COPY --from=builder /usr/local/sbt /usr/local/sbt
COPY --from=builder /usr/local/bin/sbt /usr/local/bin/sbt

# Add and use user sbtuser
RUN addgroup -g $GROUP_ID sbtuser && adduser -D -u $USER_ID -G sbtuser sbtuser
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

# Prepare sbt (warm cache)
RUN \
  umask 0002 && \
  sbt --script-version && \
  mkdir -p project && \
  echo "scalaVersion := \"${SCALA_VERSION}\"" > build.sbt && \
  echo "sbt.version=${SBT_VERSION}" > project/build.properties && \
  echo "// force sbt compiler-bridge download" > project/Dependencies.scala && \
  echo "case object Temp" > Temp.scala && \
  sbt sbtVersion && \
  sbt compile && \
  rm -r project && rm build.sbt && rm Temp.scala && rm -r target

# Link everything into root as well
# This allows users of this container to choose, whether they want to run the container as sbtuser (non-root) or as root
USER root
RUN \
  rm -rf /tmp/..?* /tmp/.[!.]* * && \
  ln -s /home/sbtuser/.cache /root/.cache && \
  ln -s /home/sbtuser/.sbt /root/.sbt && \
  if [ -d "/home/sbtuser/.ivy2" ]; then ln -s /home/sbtuser/.ivy2 /root/.ivy2; fi

# Switch working directory back to root
## Users wanting to use this container as non-root should combine the two following arguments
## -u sbtuser
## -w /home/sbtuser
WORKDIR /root

CMD ["sbt"]
