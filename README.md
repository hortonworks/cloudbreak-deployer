# Environments

## Cloudbreak Deployer

### Contributing

Install GO:
```
brew install go
```
Export GOPATH and add to PATH the $GOPATH/bin directory:

Get cloudbreak-deployer project and dependencies with GO:
```
export GO111MODULE=off
go get -d github.com/hortonworks/cloudbreak-deployer
go get -u github.com/jteeuwen/go-bindata/...
``` 

Development process happens on separate branches. Open a pull-request to contribute your changes.

To build the project:
```
cd $GOPATH/src/github.com/hortonworks/cloudbreak-deployer
# make deps and bindata only need to be run once
make bindata
make deps
make install
```

To run the unit tests:

```
make tests
```

### Snapshots

We recommend that you always use the latest release, but you might also want to check new features or bugfixes in the `master` branch.
All successful builds from the `master` branch are uploaded to the public S3 bucket. You can download it using:

```
curl -s https://raw.githubusercontent.com/hortonworks/cloudbreak-deployer/master/install-dev | sh && cbd --version
```

Instead of overwriting the released version, download it to a **local directory** and use it by referring to it as `./cbd`

```
./cbd --version
```

### Testing

Shell scripts shouldn’t raise exceptions when it comes to unit testing. [basht](https://github.com/progrium/basht) is
 used for testing. See [this link](https://github.com/progrium/basht#why-not-bats-or-shunit2) to learn why not bats or shunit2.

You must cover your bash functions with unit tests and run the test with:

```
make tests
```

### Release Process for the Clodbreak Deployer Tool

The master branch is always built on [Jenkins](http://build.eng.hortonworks.com:8080/job/cbd-container-updater/).

When you want to create a new release, run:

```
make release-next-ver
```

The `make release-next-ver` performs the following steps:

 * On the `master` branch:
    * Updates the `VERSION` file by increasing the **patch** version number (For example, from 0.5.2 to 0.5.3).
    * Updates `CHANGELOG.md` with the release date.
    * Creates a new **Unreleased** section at the top of `CHANGELOG.md`.
 * Creates a PullRequest for the release branch:
    * Creates a new branch with a name like `release-0.5.x`.
    * This branch should be the same as `origin/master`.
    * Creates a pull request on the `release` branch.

### Acceptance

Now you should test this release. You can update to it by running `curl -L -s https://github.com/hortonworks/cloudbreak-deployer/archive/release-x.y.z.tar.gz | tar -xz -C $(dirname $(which cbd))`. Comment with LGTM (Looking Good To Me).

Once the PR is merged, CircleCI will build it:

* Create a new release on [GitHub releases tab](https://github.com/hortonworks/cloudbreak-deployer/releases), with the
 help of [gh-release](https://github.com/progrium/gh-release).
* Create the git tag with `v` prefix like: `v0.0.3`.

### Configuring trusted certificates for the Java based services of Clodbreak Deployer Tool
If an external database(RDS for example) for Cloudbreak's Java based services and enable `SSL` verification are needed, CBD started to support loading certificates from the `certs/into-nssdb/` directory of your deployment.

This means that certificates from the `certs/into-nssdb/` will be loaded to an `NSS DB` instance by a new Java init container and Java based services will get this `NSS DB` on a shared volume and use it as the default trust/key-store.

**The following `Profile` file snippet is an example of how `SSL` could be configured for the Environment and FreeIPA services**
```
export ENVIRONMENT_JAVA_OPTS='-Denvironment.db.env.ssl="true"'
export ENVIRONMENT_DB_ENV_USER="postgres"
export ENVIRONMENT_DB_ENV_DB="environmentdb"
export ENVIRONMENT_DB_ENV_PASS="..."
export ENVIRONMENT_DB_HOST="tb-.....cwuvxwrz4ivx.eu-central-1.rds.amazonaws.com"

export FREEIPA_DB_ENV_USER="postgres"
export FREEIPA_DB_ENV_DB="freeipadb"
export FREEIPA_DB_ENV_PASS="..."
export FREEIPA_DB_ADDR="tb-....cwuvxwrz4ivx.eu-central-1.rds.amazonaws.com"
export FREEIPA_JAVA_OPTS='-Dfreeipa.db.env.ssl="true"'