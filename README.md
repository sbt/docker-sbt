# Daily built sbt Docker images

This repository provides [sbt](http://www.scala-sbt.org) Docker files and images for building [Scala](http://www.scala-lang.org) projects. The images install sbt (which resolves the project's Scala version itself); a standalone `scala` CLI is not bundled.

As we think referencing unstable versions is a bad idea we don't publish a `latest` tag. The full ("fat") tags consist of three parts: `<JDK version>_<sbt version>_<Scala version>`, where a trivial project is pre-compiled so that **both sbt and the Scala compiler are warmed** (downloaded and cached in the image).

There are also **light** images. These do **no warmup at all** - neither sbt nor
Scala. They simply ship the JDK with sbt installed and the user/permissions set
up; sbt downloads its own runtime, the Scala toolchain, and your dependencies on
first run. The point is convenience (a ready-to-use, correctly configured sbt
environment), not a warm cache - warming a specific sbt/Scala only pays off in
the fat images, and a light image's pinned versions would rarely match your
project anyway (sbt resolves the Scala version your project needs, and your
`project/build.properties` pins the exact sbt). So the light tags carry no Scala
part and only track the sbt *line* (`1.x` / `2.x`), which always rolls forward to
the latest release. Each light image is published under two tags:

* `<JDK major>_<sbt line>`, e.g. `eclipse-temurin-25_1.x` - JDK and sbt both roll
  forward to the latest. Convenient, nothing to update.
* `<JDK version>_<sbt line>`, e.g. `eclipse-temurin-25.0.1_8_1.x` - pin the JDK
  (plain Dependabot can bump it), sbt still rolls.

Light images are built for **sbt 1.x and sbt 2.x** (sbt 2.x requires JDK 17+),
on Eclipse Temurin and Amazon Corretto. The Alpine variants are 1.x only for now:
the sbt 2 native launcher does not run on musl yet ([sbt/sbt#9319](https://github.com/sbt/sbt/issues/9319)).

```
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-25_1.x          # light, JDK + sbt 1.x latest
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-25.0.1_8_2.x    # light, pinned JDK + sbt 2.x latest
docker run -it --rm sbtscala/scala-sbt:amazoncorretto-al2023-25_2.x     # light, Corretto + sbt 2.x latest
```

Images are updated daily

Available JDK base images:
* eclipse-temurin
* graalvm-community
* graalvm-jdk-community (compact GraalVM JDK; smaller, but no `native-image` - use graalvm-community if you need it)
* amazoncorretto

## Where to get images

The images are published at [Docker Hub](https://hub.docker.com/u/sbtscala)

For a list of all available tags see https://hub.docker.com/r/sbtscala/scala-sbt/tags

Older tags are available at: https://hub.docker.com/r/hseeberger/scala-sbt/tags

## Installation ##

1. Install [Docker](https://www.docker.com)
2. Pull [automated build](https://hub.docker.com/r/sbtscala/scala-sbt/) from public [Docker Hub Registry](https://registry.hub.docker.com):
```
docker pull sbtscala/scala-sbt:eclipse-temurin-21.0.12_8_1.13.0_3.9.0
```
Alternatively, you can build an image from the remote Dockerfile:
```
docker build \
  --build-arg BASE_IMAGE_TAG="21.0.12_8-jdk" \
  --build-arg SBT_VERSION="1.13.0" \
  --build-arg SCALA_VERSION="3.9.0" \
  --build-arg USER_ID=1001 \
  --build-arg GROUP_ID=1001 \
  -t sbtscala/scala-sbt \
  "github.com/sbt/docker-sbt.git#:eclipse-temurin"
```

## Usage ##

```
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-21.0.12_8_1.13.0_3.9.0
```

### Choosing a tag ###

* Light, rolling (`eclipse-temurin-25_2.x`): nothing to update; your
  `project/build.properties` picks the exact sbt anyway.
* Light, pinned JDK (`eclipse-temurin-25.0.4_7_2.x`): reproducible JDK, bumped by
  Dependabot or Renovate.
* Fat (`eclipse-temurin-25.0.4_7_1.13.0_3.9.0`): sbt and one Scala version
  already downloaded. Only worth it when they match your build; otherwise keep
  a cache between runs (below) or [warm your own image](#warming-your-own-image).

### Building a project ###

Mount the project and run sbt in it:

```
docker run -it --rm -v "$PWD":/app -w /app sbtscala/scala-sbt:eclipse-temurin-25_2.x sbt test
```

Each run starts from the image's cache, so sbt and your dependencies are
downloaded again every time. Keep the cache in named volumes to reuse it (an
empty volume is first filled with what the image already has cached):

```
docker run -it --rm \
  -v sbt-cache:/home/sbtuser/.cache \
  -v sbt-home:/home/sbtuser/.sbt \
  -v "$PWD":/app -w /app \
  sbtscala/scala-sbt:eclipse-temurin-25_2.x sbt test
```

The container runs as root by default, so with Docker the files sbt writes to
the mounted project (`target/`, ...) are owned by root on the host. Running as
your own uid (`-u $(id -u):$(id -g)`) does not work well yet: see
[#434](https://github.com/sbt/docker-sbt/issues/434).

### In a Dockerfile ###

Use the image as the build stage of a multi-stage build and copy only the
packaged app into a JRE image. This example packages a single jar with
[sbt-assembly](https://github.com/sbt/sbt-assembly) (add
`addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "2.5.0")` to
`project/plugins.sbt`):

```dockerfile
FROM sbtscala/scala-sbt:eclipse-temurin-25_2.x AS build
USER sbtuser
WORKDIR /home/sbtuser/app
# Build definition first: dependencies are only resolved again when it changes
COPY --chown=sbtuser:0 build.sbt ./
COPY --chown=sbtuser:0 project/ project/
RUN sbt update
COPY --chown=sbtuser:0 . .
# sbt 2 writes the jar to target/out/jvm/scala-<version>/<name>/
RUN sbt assembly && cp target/out/jvm/scala-*/*/*-assembly-*.jar app.jar

FROM eclipse-temurin:25-jre
COPY --from=build /home/sbtuser/app/app.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

The jar path is the sbt 2 layout; with sbt 1.x the jar is in
`target/scala-<version>/`, so copy `target/scala-*/*-assembly-*.jar` instead.
Add `target/` and `project/target/` to `.dockerignore`.

### In CI ###

In a GitHub Actions container job:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container: sbtscala/scala-sbt:eclipse-temurin-25_2.x
    steps:
      - uses: actions/checkout@v7
      - run: sbt test
```

To cache dependencies between runs, run on the runner itself instead, with
[`actions/setup-java`](https://github.com/actions/setup-java) (`cache: sbt`) and
[`sbt/setup-sbt`](https://github.com/sbt/setup-sbt).

### Alternative commands ###
The container contains `bash` and `sbt`.

```
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-21.0.12_8_1.13.0_3.9.0 bash
```

The standalone `scala` CLI is not bundled: sbt resolves its own Scala per project,
so it was unused for sbt builds. If you want Scala without sbt (scripts, the REPL),
use the [Scala CLI](https://github.com/VirtusLab/scala-cli) image
[`virtuslab/scala-cli`](https://hub.docker.com/r/virtuslab/scala-cli).

### Non-root ###
The container is prepared to be used with a non-root user called `sbtuser`

```
docker run -it --rm -u sbtuser -w /home/sbtuser sbtscala/scala-sbt:eclipse-temurin-21.0.12_8_1.13.0_3.9.0
```

You can also run as an arbitrary user id. `HOME` is set to `/home/sbtuser`, whose
contents are group-writable for the root group (gid 0) that an arbitrary
`-u <uid>` belongs to by default:

```
docker run -it --rm -u 1234 -w /home/sbtuser sbtscala/scala-sbt:eclipse-temurin-21.0.12_8_1.13.0_3.9.0
```

## Warming your own image ##

The fat images only warm a trivial project with the sbt and Scala versions we
picked. Warming your own image from a light tag caches exactly what your build
uses: its sbt version, Scala version, plugins and library dependencies. Copy
the build definition before the sources, so the warm layer is only rebuilt when
the build changes:

```dockerfile
FROM sbtscala/scala-sbt:eclipse-temurin-25_2.x
USER sbtuser
WORKDIR /home/sbtuser/app
# Build definition only: this layer is rebuilt only when the build changes
COPY --chown=sbtuser:0 build.sbt ./
COPY --chown=sbtuser:0 project/ project/
# Resolves the project's sbt, Scala, plugins and library dependencies
RUN umask 0002 && sbt update
COPY --chown=sbtuser:0 . .
```

Add `target/` and `project/target/` to `.dockerignore` so local build output is
not copied in.

If you only need a warm cache in CI, caching it there avoids maintaining an
image at all (see [In CI](#in-ci)).

The fat images are no longer extended (there are no fat sbt 2 images, for
example); new combinations are only added as light images.

## Automated updates with Renovate ##

Because the tags combine three independent versions (`<JDK>_<sbt>_<Scala>`),
[Renovate](https://docs.renovatebot.com) needs a custom `versioning` to parse
them. The example below pins the image variant (e.g. `eclipse-temurin`) and the
sbt/Scala versions you already use, and proposes updates whenever the JDK part
(`<major>.<minor>.<patch>_<build>`) is bumped:

```json
{
  "packageRules": [
    {
      "description": "Parse sbtscala/scala-sbt tags: <JDK>_<sbt>_<Scala>",
      "matchDatasources": ["docker"],
      "matchPackageNames": ["sbtscala/scala-sbt"],
      "versioning": "regex:^(?<compatibility>.*)-(?<major>\\d+)\\.(?<minor>\\d+)\\.(?<patch>\\d+)_(?<build>\\d+)_\\d+\\.\\d+\\.\\d+_\\d+\\.\\d+\\.\\d+$"
    }
  ]
}
```

The `compatibility` group keeps Renovate within the same image variant, and the
trailing `_\d+\.\d+\.\d+_\d+\.\d+\.\d+` matches (but ignores) the sbt and Scala
parts. Note that JDK bumps in this repo can lag slightly behind upstream JDK
releases.

## Contribution policy ##

Contributions via GitHub pull requests are gladly accepted from their original author. Along with any pull requests, please state that the contribution is your original work and that you license the work to the project under the project's open source license. Whether or not you state this explicitly, by submitting any copyrighted material via pull request, email, or other means you agree to license the material under the project's open source license and warrant that you have the legal authority to do so.


## License ##

This code is open source software licensed under the [Apache 2.0 License]("http://www.apache.org/licenses/LICENSE-2.0.html").
