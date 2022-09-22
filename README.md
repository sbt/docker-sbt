# Scala and sbt Dockerfile

This repository provides [Scala](http://www.scala-lang.org) and [sbt](http://www.scala-sbt.org) Docker files and images.

As we think referencing unstable versions is a bad idea we don't publish a `latest` tag. Our tags consists of three parts: `<JDK version>_<sbt version>_<Scala version>`.

Images are updated daily

Available JDK base images:
* eclipse-temurin - recommended
* openjdk - [deprecated](https://hub.docker.com/_/openjdk?tab=description)
* openjdk-oraclelinux8
* graalvm-ce

## Where to get images

The images are published at [Docker Hub](https://hub.docker.com/u/sbtscala)

For a list of all available tags see https://hub.docker.com/r/sbtscala/scala-sbt/tags

Older tags are available at: https://hub.docker.com/r/hseeberger/scala-sbt/tags

## Installation ##

1. Install [Docker](https://www.docker.com)
2. Pull [automated build](https://hub.docker.com/r/sbtscala/scala-sbt/) from public [Docker Hub Registry](https://registry.hub.docker.com):
```
docker pull sbtscala/scala-sbt:eclipse-temurin-17.0.4_1.7.1_3.2.0
```
Alternatively, you can build an image from the remote Dockerfile:
```
docker build \
  --build-arg BASE_IMAGE_TAG="17.0.4.1_1-jdk" \
  --build-arg SBT_VERSION="1.7.1" \
  --build-arg SCALA_VERSION="3.2.0" \
  --build-arg USER_ID=1001 \
  --build-arg GROUP_ID=1001 \
  -t sbtscala/scala-sbt \
  "github.com/sbt/docker-sbt.git#:eclipse-temurin"
```

## Usage ##

```
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-17.0.4_1.7.1_3.2.0
```

### Alternative commands ###
The container contains `bash`, `scala` and `sbt`.

```
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-17.0.4_1.7.1_3.2.0 scala
```

### Non-root ###
The container is prepared to be used with a non-root user called `sbtuser`

```
docker run -it --rm -u sbtuser -w /home/sbtuser sbtscala/scala-sbt:eclipse-temurin-17.0.4_1.7.1_3.2.0
```

## Contribution policy ##

Contributions via GitHub pull requests are gladly accepted from their original author. Along with any pull requests, please state that the contribution is your original work and that you license the work to the project under the project's open source license. Whether or not you state this explicitly, by submitting any copyrighted material via pull request, email, or other means you agree to license the material under the project's open source license and warrant that you have the legal authority to do so.


## License ##

This code is open source software licensed under the [Apache 2.0 License]("http://www.apache.org/licenses/LICENSE-2.0.html").
