#
# Scala and sbt Dockerfile
#
# https://github.com/hseeberger/scala-sbt
#

# Pull base image
FROM dockerfile/java:oracle-java8

# Install Scala
RUN \
  cd /root && \
  curl -o scala-2.11.4.tgz http://downloads.typesafe.com/scala/2.11.4/scala-2.11.4.tgz && \
  tar -xf scala-2.11.4.tgz && \
  rm scala-2.11.4.tgz && \
  echo >> /root/.bashrc && \
  echo 'export PATH=~/scala-2.11.4/bin:$PATH' >> /root/.bashrc

# Install sbt
RUN \
  curl -L -o sbt-0.13.7.deb https://dl.bintray.com/sbt/debian/sbt-0.13.7.deb && \
  dpkg -i sbt-0.13.7.deb && \
  rm sbt-0.13.7.deb && \
  apt-get update && \
  apt-get install sbt

# Define working directory
WORKDIR /root
