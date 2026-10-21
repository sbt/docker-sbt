# Daily built sbt Docker images

This repository provides [sbt](http://www.scala-sbt.org) Docker files and images for building [Scala](http://www.scala-lang.org) projects. The images install sbt (which resolves the project's Scala version itself); a standalone `scala` CLI is not bundled.

As we think referencing unstable versions is a bad idea we don't publish a `latest` tag. Images are updated daily.

## Light images (recommended) ##

Light images ship the JDK with sbt installed and the user/permissions set up.
They do **no warmup**: sbt downloads its own runtime, the Scala toolchain, and
your dependencies on first run. The point is a ready-to-use, correctly
configured sbt environment; your `project/build.properties` picks the exact sbt
and sbt resolves the Scala version your project needs. To avoid downloading
everything on every run, keep a cache between runs or
[warm your own image](#warming-your-own-image).

The tags carry no Scala part and only track the sbt *line* (`1.x` / `2.x`),
which always rolls forward to the latest release. Each light image is published
under two tags:

* `<JDK major>_<sbt line>`, e.g. `eclipse-temurin-25_2.x` - JDK and sbt both roll
  forward to the latest. Convenient, nothing to update.
* `<JDK version>_<sbt line>`, e.g. `eclipse-temurin-25.0.4_7_2.x` - pin the JDK
  (bumped by Dependabot, or by [Renovate](#automated-updates-with-renovate)),
  sbt still rolls.

```
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-25_2.x          # JDK + sbt 2.x latest
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-25.0.4_7_1.x    # pinned JDK + sbt 1.x latest
docker run -it --rm sbtscala/scala-sbt:amazoncorretto-al2023-25_2.x    # Corretto + sbt 2.x latest
```

Light images are built for **sbt 1.x and sbt 2.x** (sbt 2.x requires JDK 17+) on
JDK 17, 21 and 25 of:

* eclipse-temurin
* eclipse-temurin-alpine (sbt 1.x only for now: the sbt 2 native launcher does
  not run on musl yet, [sbt/sbt#9319](https://github.com/sbt/sbt/issues/9319))
* amazoncorretto-al2023 (amd64 only)

## Fat images (deprecated) ##

The fat tags consist of three parts, `<JDK version>_<sbt version>_<Scala version>`
(e.g. `eclipse-temurin-25.0.4_7_1.13.0_3.9.0`), where a trivial project is
pre-compiled so that sbt and that Scala compiler are cached in the image.

**Fat images are deprecated** and will be removed in a future release. They only
help when your build uses exactly the sbt and Scala version we picked, so they
are no longer extended: there are no fat sbt 2 images, and new combinations are
only added as light images. Tags that were already published stay available on
Docker Hub. Move to a light image, and keep a cache between runs or
[warm your own image](#warming-your-own-image) if you need a warm start.

Fat images are built for sbt 1.x on eclipse-temurin, eclipse-temurin-alpine,
amazoncorretto, graalvm-community and graalvm-jdk-community (compact GraalVM
JDK; smaller, but no `native-image`). GraalVM is not available as a light image
yet.

## Where to get images ##

The images are published at [Docker Hub](https://hub.docker.com/u/sbtscala)

For a list of all available tags see https://hub.docker.com/r/sbtscala/scala-sbt/tags

Older tags are available at: https://hub.docker.com/r/hseeberger/scala-sbt/tags

## Usage ##

```
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-25_2.x
```

### Choosing a tag ###

* Light, rolling (`eclipse-temurin-25_2.x`): nothing to update; your
  `project/build.properties` picks the exact sbt anyway.
* Light, pinned JDK (`eclipse-temurin-25.0.4_7_2.x`): reproducible JDK, bumped by
  Dependabot or Renovate.
* Fat (`eclipse-temurin-25.0.4_7_1.13.0_3.9.0`): deprecated, see
  [above](#fat-images-deprecated).

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
the mounted project (`target/`, ...) are owned by root on the host. To run as
another uid, see [Arbitrary user ids](#arbitrary-user-ids).

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
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-25_2.x bash
```

The standalone `scala` CLI is not bundled: sbt resolves its own Scala per project,
so it was unused for sbt builds. If you want Scala without sbt (scripts, the REPL),
use the [Scala CLI](https://github.com/VirtusLab/scala-cli) image
[`virtuslab/scala-cli`](https://hub.docker.com/r/virtuslab/scala-cli).

### Non-root ###
The container is prepared to be used with a non-root user called `sbtuser`

```
docker run -it --rm -u sbtuser -w /home/sbtuser sbtscala/scala-sbt:eclipse-temurin-25_2.x
```

### Arbitrary user ids ###
You can also run as an arbitrary user id, as OpenShift does. `HOME` is set to
`/home/sbtuser`, whose contents are group-writable for the root group (gid 0)
that `-u <uid>` joins by default, so keep that group (`-u <uid>` or
`-u <uid>:0`, not `-u <uid>:<gid>`).

The JVM takes its home from the uid's passwd entry rather than `$HOME`, so sbt
can miss `/home/sbtuser`: it then ignores the image's cache and writes `.sbt`
and `.cache` into the working directory. This happens:

* On Podman with any JDK: Podman adds a passwd entry for the uid with the
  working directory as its home. `--passwd=false` avoids that on JDK 21+.
* On JDK 17 when the uid has no passwd entry (Docker): the home becomes `?`, so
  sbt writes into a `?` directory
  ([sbt/sbt#9931](https://github.com/sbt/sbt/issues/9931)). JDK 21+ fall back to
  `$HOME`.

Point sbt at the image's home to avoid both:

```
docker run -it --rm -u 1234 -w /home/sbtuser -e SBT_OPTS=-Duser.home=/home/sbtuser sbtscala/scala-sbt:eclipse-temurin-25_2.x
```

## Warming your own image ##

Warming your own image from a light tag caches exactly what your build uses:
its sbt version, Scala version, plugins and library dependencies. Copy the build
definition before the sources, so the warm layer is only rebuilt when the build
changes:

```dockerfile
FROM sbtscala/scala-sbt:eclipse-temurin-25_2.x
USER sbtuser
WORKDIR /home/sbtuser/app
# Build definition only: this layer is rebuilt only when the build changes
COPY --chown=sbtuser:0 build.sbt ./
COPY --chown=sbtuser:0 project/ project/
# Resolves the project's sbt, Scala, plugins and library dependencies.
# --server keeps sbt 2 from leaving a background server running; the build
# output and sbt's temp files are removed as other uids can't reuse them.
RUN umask 0002 && sbt --server update && \
    rm -rf target project/target /tmp/.sbt* /tmp/hsperfdata_sbtuser
COPY --chown=sbtuser:0 . .
# Make the project writable for arbitrary uids (root group) as well
USER root
RUN chgrp -R 0 . && chmod -R g=u .
USER sbtuser
```

Add `target/` and `project/target/` to `.dockerignore` so local build output is
not copied in.

If you only need a warm cache in CI, caching it there avoids maintaining an
image at all (see [In CI](#in-ci)).

## Building the image yourself ##

You can build an image from the remote Dockerfile. An empty `SCALA_VERSION`
builds a light image:

```
docker build \
  --build-arg BASE_IMAGE_TAG="25.0.4_7-jdk" \
  --build-arg SBT_VERSION="2.0.11" \
  --build-arg SCALA_VERSION="" \
  --build-arg USER_ID=1001 \
  --build-arg GROUP_ID=1001 \
  -t sbtscala/scala-sbt \
  "github.com/sbt/docker-sbt.git#:eclipse-temurin"
```

## Automated updates with Renovate ##

Rolling light tags (`eclipse-temurin-25_2.x`) need no updates. To have
[Renovate](https://docs.renovatebot.com) bump a pinned light tag when a new JDK
is published, give it a custom `versioning` that parses the JDK part
(`<major>.<minor>.<patch>[.<build>][_<revision>]`) and stays on your sbt line
(here `2.x`; use `_1\\.x$` for sbt 1.x):

```json
{
  "packageRules": [
    {
      "description": "Parse sbtscala/scala-sbt light tags: <JDK>_<sbt line>",
      "matchDatasources": ["docker"],
      "matchPackageNames": ["sbtscala/scala-sbt"],
      "versioning": "regex:^(?<compatibility>.*)-(?<major>\\d+)\\.(?<minor>\\d+)\\.(?<patch>\\d+)(?:\\.(?<build>\\d+))?(?:_(?<revision>\\d+))?_2\\.x$"
    }
  ]
}
```

The `compatibility` group keeps Renovate within the same image variant (e.g.
`eclipse-temurin` or `amazoncorretto-al2023`). Note that JDK bumps in this repo
can lag slightly behind upstream JDK releases.

For the deprecated fat tags (`<JDK>_<sbt>_<Scala>`), use this `versioning`
instead; the trailing groups match (but ignore) the sbt and Scala parts:

```
regex:^(?<compatibility>.*)-(?<major>\\d+)\\.(?<minor>\\d+)\\.(?<patch>\\d+)(?:\\.(?<build>\\d+))?_(?<revision>\\d+)_\\d+\\.\\d+\\.\\d+_\\d+\\.\\d+\\.\\d+$
```

## Contribution policy ##

Contributions via GitHub pull requests are gladly accepted from their original author. Along with any pull requests, please state that the contribution is your original work and that you license the work to the project under the project's open source license. Whether or not you state this explicitly, by submitting any copyrighted material via pull request, email, or other means you agree to license the material under the project's open source license and warrant that you have the legal authority to do so.


## License ##

This code is open source software licensed under the [Apache 2.0 License]("http://www.apache.org/licenses/LICENSE-2.0.html").
