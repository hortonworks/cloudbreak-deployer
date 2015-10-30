##Overview

Cloudbreak is a cloud agnostic Hadoop as a Service API. Abstracts the provisioning and ease management and monitoring of on-demand HDP clusters in different virtual environments. Once it is deployed in your favorite servlet container exposes a REST API allowing to span up Hadoop clusters of arbitrary sizes on your selected cloud provider. Provisioning Hadoop has never been easier.
Cloudbreak is built on the foundation of cloud providers API (Microsoft Azure, Amazon AWS, Google Cloud Platform, OpenStack), Apache Ambari, Docker containers, Swarm and Consul.

For a detailed overview please follow this [link](overview.md)

Cloudbreak has two main components - the [Cloudbreak deployer](http://sequenceiq.com/cloudbreak-deployer) and the Cloudbreak application, which is made up from Microservices (Cloudbreak, Uluwatu, Sultans, ...). Cloudbreak deployer helps you to deploy the Cloudbreak application automatically in environments with Docker support. Once the Cloudbreak application is deployed you can use it to provision HDP clusters in different cloud environments.

##Technology

For an architectural overview of the [Cloudbreak deployer](http://sequenceiq.com/cloudbreak-deployer) and the Cloudbreak application please follow this [link](technology.md).

##Process Overview

The full proceess to be able to use an HDP cluster includes the following steps:

- **Cloudbreak Deployer Installation**: You need to install Cloudbreak Deployer which is a small cli tool called
`cbd`. It will help you to deploy the CloudBreak Application consisting several Docker containers. You have
finished this step if you can issue `cbd --version`.
- **CloudBreak Deployment**: Once you have installed Cloudbreak Deployer (cbd), it will start up several
Docker containers: CloudBreak API, CloudBreak UI (called Uluwatu), Identity Server, and supporting databases.
You have finished this step, if you are able to login in your browser to Cloudbreak UI (Uluwatu).
- **HDP Cluster Provisioning**: To be able to provision a HDP cluster, you will use the browser, to:
  - Create Credentials: You give access to Cloudbreak, to act on behalf of you, and start resources on the
    cloud provider.
  - Create Resources: Optionally you can define infrastructure parameters, such as, instance type,
    memory size, disk type/size, network ...
  - Blueprint configuration: You can choose which Ambari Blueprint you want to use (or upload a custom one)
    and assign hostgroups to resource types (created in the previous step)
  - Create Cluster: You define the region, where you want to create the HDP cluster. Once Cloudbreak
    recognize that Ambari Server is up and running, it posts the configured blueprint to it, which
    triggers a cluster wide HDP component installation process.

##Installation

Currently only **Linux** and **OSX** 64 bit binaries are released for Cloudbreak Deployer. For anything else we can create a special Docker container - please contact us. The deployment itself needs only **Docker 1.7.0** or later. You can install the Cloudbreak installation anywhere (on-prem or cloud VMs), however we suggest to installed it as close to the desired HDP clusters as possible. For further information check the **Provider** section of the documentation.

**On-prem installation**

For on premise installations of the Cloudbreak application please follow the [link](onprem.md)

**AWS based installation**

We have pre-built custom cloud images with Cloudbreak deployer pre-configured. Following the steps will guide you through the provider specific configuration and launching clusters using that provider.

You can follow the AWS provider specific documentation using this [link](aws.md)

**Azure based installation**

We have pre-built custom cloud images with Cloudbreak deployer pre-configured. Following the steps will guide you through the provider specific configuration and launching clusters using that provider.

You can follow the Azure provider specific documentation using this [link](azure.md)

**GCP based installation**

We have pre-built custom cloud images with Cloudbreak deployer pre-configured. Following the steps will guide you through the provider specific configuration and launching clusters using that provider.

You can follow the GCP provider specific documentation using this [link](gcp.md)

**OpenStack based installation**

We have pre-built custom cloud images with Cloudbreak deployer pre-configured. Following the steps will guide you through the provider specific configuration and launching clusters using that provider.

You can follow the OpenStack provider specific documentation using this [link](openstack.md)

##Release notes - 1.1.0

| Components    | GA            | Tech preview  |
| ------------- |:-------------:| -----:|
| AWS   | yes |
| Azure ARM   | yes      |    |
| Azure ARM   | yes      |    |
| GCP  | yes      |    |
| OpenStack Juno   |       | yes   |
| SPI interface   |       | yes   |
| CLI/shell  |   yes    |    |
| Recipes  |       | yes   |
| Kerberos   |       | yes   |

**Credits**

This tool, and the PR driven release, is inspired from [glidergun](https://github.com/gliderlabs/glidergun). Actually it
could be a fork of it. The reason it’s not a fork, because we wanted to have our own binary with all modules
built in, so only a single binary is needed.
