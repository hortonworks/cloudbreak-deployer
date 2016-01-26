# Install Cloudbreak Deployer

To install Cloudbreak Deployer on your selected environment you have to follow the steps below. The instruction describe a CentOS-based installation.

> **IMPORTANT:** If you plan to use Cloudbreak on Azure, you **must** use the [Azure Setup](azure.md) instructions to install and configure the Cloudbreak.

## System Requirements

To run the Cloudbreak Deployer and install the Cloudbreak Application, you must meet the following system requirements:

 * RHEL / CentOS / Oracle Linux 7 (64-bit)
 * Docker 1.8.3 (or later)

> You can install Cloudbreak on Mac OS X "Darwin" for **evaluation purposes only**. This operating system is not supported for a production deployment of Cloudbreak.

Make sure you opened the following ports:

 * SSH (22)
 * Ambari (8080)
 * Identity server (8089)
 * Cloudbreak GUI (3000)
 * User authentication (3001)

Assume **root** privileges with this command:

```
sudo su
```

To permanently disable **SELinux** set SELINUX=disabled in /etc/selinux/config This ensures that SELinux does not turn itself on after you reboot the machine:

```
setenforce 0 && sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
```

You need to install iptables-services, otherwise the 'iptables save' command will not be available:

```
yum -y install iptables-services net-tools unzip
```

Please configure your iptables on your machine:

```
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
```

Configure a custom Docker repository for installing the correct version of Docker:

```
cat > /etc/yum.repos.d/docker.repo <<"EOF"
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF
```

Then you are able to install the Docker service:

```
yum install -y docker-engine-1.8.3
```

Configure your installed Docker service:

```
cat > /usr/lib/systemd/system/docker.service <<"EOF"
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network.target docker.socket
Requires=docker.socket

[Service]
ExecStart=/usr/bin/docker -d -H fd:// -H tcp://0.0.0.0:2376 --selinux-enabled=false --storage-driver=devicemapper --storage-opt=dm.basesize=30G
MountFlags=slave

[Install]
WantedBy=multi-user.target
EOF
```

Remove docker folder and restart Docker service:

```
systemctl daemon-reload && service docker start && systemctl enable docker.service
```

## Install Cloudbreak deployer

Install the Cloudbreak deployer and unzip the platform specific single binary to your PATH. The one-liner way is:

```
curl https://raw.githubusercontent.com/sequenceiq/cloudbreak-deployer/master/install-latest | sh && cbd --version
```

Once the Cloudbreak deployer is installed, you can start to setup the Cloudbreak application.

## Initialize your Profile

First initialize cbd by creating a `Profile` file:

```
cbd init
```

It will create a `Profile` file in the current directory. Please edit the file - the only required
configuration is the `PUBLIC_IP`. This IP will be used to access the Cloudbreak UI
(called Uluwatu). In some cases the `cbd` tool tries to guess it, if can't than will give a hint.

## Generate your Profile

You are done with the configuration of Cloudbreak deployer. The last thing you have to do is to regenerate the configurations in order to take effect.

```
rm *.yml
cbd generate
```

This command applies the following steps:

- creates the **docker-compose.yml** file that describes the configuration of all the Docker containers needed for the Cloudbreak deployment.
- creates the **uaa.yml** file that holds the configuration of the identity server used to authenticate users to Cloudbreak.

## Start Cloudbreak

To start the Cloudbreak application use the following command.
This will start all the Docker containers and initialize the application. It will take a few minutes until all the services start.

```
cbd start
```

>Launching it first will take more time as it downloads all the docker images needed by Cloudbreak.

After the `cbd start` command finishes you can check the logs of the Cloudbreak server with this command:

```
cbd logs cloudbreak
```
>Cloudbreak server should start within a minute - you should see a line like this: `Started CloudbreakApplication in 36.823 seconds`

## Next steps

Now that you all pre-requisites for Cloudbreak are in place you can follow with the **cloud provider specific** configuration. Based on the location where you plan to launch HDP clusters select one of the providers documentation and follow the steps from the **Deployment** section.

You can find the provider specific documentations here:

* [AWS](aws.md)
* [Azure](azure.md)
* [GCP](gcp.md)
* [OpenStack](openstack.md)
