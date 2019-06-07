#
# Scala and sbt Dockerfile
#
# https://github.com/hseeberger/scala-sbt
#

# Pull base image
FROM openjdk:11.0.2

# Env variables
ENV SCALA_VERSION 2.12.8
ENV SBT_VERSION 1.2.8

# Install Scala
## Piping curl directly in tar
RUN \
  curl -fsL https://downloads.typesafe.com/scala/$SCALA_VERSION/scala-$SCALA_VERSION.tgz | tar xfz - -C /root/ && \
  echo >> /root/.bashrc && \
  echo "export PATH=~/scala-$SCALA_VERSION/bin:$PATH" >> /root/.bashrc

# Install sbt
RUN \
  curl -L -o sbt-$SBT_VERSION.deb https://dl.bintray.com/sbt/debian/sbt-$SBT_VERSION.deb && \
  dpkg -i sbt-$SBT_VERSION.deb && \
  rm sbt-$SBT_VERSION.deb && \
  apt-get update && \
  apt-get install sbt && \
  sbt sbtVersion && \
  mkdir project && \
  echo "scalaVersion := \"${SCALA_VERSION}\"" > build.sbt && \
  echo "sbt.version=${SBT_VERSION}" > project/build.properties && \
  echo "case object Temp" > Temp.scala && \
  sbt compile && \
  rm -r project && rm build.sbt && rm Temp.scala && rm -r target

# Add and use user sbt
RUN groupadd --gid 1001 sbtuser && useradd --gid 1001 --uid 1001 sbtuser --shell /bin/bash
RUN chown -R sbtuser:sbtuser /opt
RUN mkdir /home/sbtuser && chown -R sbtuser:sbtuser /home/sbtuser
RUN mkdir /logs && chown -R sbtuser:sbtuser /logs
USER sbtuser

# Define working directory
WORKDIR /home/sbtuser

CMD ["sbt"]
