# Daily built sbt Docker images

This repository provides [sbt](http://www.scala-sbt.org) Docker files and images for building [Scala](http://www.scala-lang.org) projects. The images install sbt (which resolves the project's Scala version itself); a standalone `scala` CLI is not bundled.

As we think referencing unstable versions is a bad idea we don't publish a `latest` tag. The full ("fat") tags consist of three parts: `<JDK version>_<sbt version>_<Scala version>`, where a trivial project is pre-compiled so the Scala compiler is also warmed.

There are also **light** images (no Scala warmup). sbt resolves the Scala version your
project needs at build time, so the Scala part is unnecessary; and your
`project/build.properties` already pins the exact sbt, so the light tags only
track the sbt *line* (`1.x` / `2.x`), which always rolls forward to the latest
release. Each light image is published under two tags:

* `<JDK major>_<sbt line>`, e.g. `eclipse-temurin-25_1.x` - JDK and sbt both roll
  forward to the latest. Convenient, nothing to update.
* `<JDK version>_<sbt line>`, e.g. `eclipse-temurin-25.0.1_8_1.x` - pin the JDK
  (plain Dependabot can bump it), sbt still rolls.

Light images are built for **sbt 1.x and sbt 2.x** (sbt 2.x requires JDK 17+).

```
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-25_1.x          # light, JDK + sbt 1.x latest
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-25.0.1_8_2.x    # light, pinned JDK + sbt 2.x latest
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
docker pull sbtscala/scala-sbt:eclipse-temurin-21.0.8_9_1.12.11_3.8.4
```
Alternatively, you can build an image from the remote Dockerfile:
```
docker build \
  --build-arg BASE_IMAGE_TAG="21.0.8_9-jdk" \
  --build-arg SBT_VERSION="1.12.11" \
  --build-arg SCALA_VERSION="3.8.4" \
  --build-arg USER_ID=1001 \
  --build-arg GROUP_ID=1001 \
  -t sbtscala/scala-sbt \
  "github.com/sbt/docker-sbt.git#:eclipse-temurin"
```

## Usage ##

```
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-21.0.8_9_1.12.11_3.8.4
```

### Alternative commands ###
The container contains `bash` and `sbt`.

```
docker run -it --rm sbtscala/scala-sbt:eclipse-temurin-21.0.8_9_1.12.11_3.8.4 bash
```

The standalone `scala` CLI is not bundled: sbt resolves its own Scala per project,
so it was unused for sbt builds. If you want Scala without sbt (scripts, the REPL),
use the [Scala CLI](https://github.com/VirtusLab/scala-cli) image
[`virtuslab/scala-cli`](https://hub.docker.com/r/virtuslab/scala-cli).

### Non-root ###
The container is prepared to be used with a non-root user called `sbtuser`

```
docker run -it --rm -u sbtuser -w /home/sbtuser sbtscala/scala-sbt:eclipse-temurin-21.0.8_9_1.12.11_3.8.4
```

You can also run as an arbitrary user id. `HOME` is set to `/home/sbtuser`, whose
contents are group-writable for the root group (gid 0) that an arbitrary
`-u <uid>` belongs to by default:

```
docker run -it --rm -u 1234 -w /home/sbtuser sbtscala/scala-sbt:eclipse-temurin-21.0.8_9_1.12.11_3.8.4
```

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
