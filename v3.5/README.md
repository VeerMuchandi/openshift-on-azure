# Installing up OpenShift on Azure 

### Set up Hosts (if not done before)
**If using a jump server other than master and if you already provisioned your VMs you can ignore this stage and move to the next one **

Spin up a master and a few node hosts on the AWS environment  

* 2 cores and 8GB RAM or higher
* 2 extra disks on the master 
  *  30GB or higher for docker storage
  *  30GB or higher for registry storage
* Master needs a public IP
* Configure a security group for the master that allows
 * TCP SSH port 22
 * HTTP port 80
 * HTTPS port 443
 * TCP port 8443 for MasterAPI
 * TCP port 9090 for Cockpit
 * TCP port range 2379-2380
* Set up your sshkey to be able to log into the master


We will use master as our jump host to install OpenShift using Ansible. 
 
*  Log into the master
* `sudo bash` and then as root user subscribe to RHN
* install `atomic-openshift-utils` and this will install ansible

 ```
 subscription-manager register
 subscription-manager attach --pool <<your poolid>> 
 subscription-manager repos --disable="*"
 subscription-manager repos     --enable="rhel-7-server-rpms"     --enable="rhel-7-server-extras-rpms"     --enable="rhel-7-server-ose-3.5-rpms"
 yum install -y atomic-openshift-utils
```

* Switch back to regular user

	```
	ssh-keygen
	```	

* Use this key (`cat ~/.ssh/id_rsa.pub` as the login key for the other hosts. Configure this from Azure console  Node->Support+Troubleshooting->Reset Password

	Now you should be able to ssh from master host to the other (node) hosts.

* Install git
```yum install git -y ```


* `git clone` the repository (https://github.com/VeerMuchandi/openshift-on-azure) onto the master host. For now using context-dir v3.3. You should now get the required ansible playbooks to prep the hosts

### Prepare the Hosts

* Update the `hosts.openshiftprep` file with the internal ip addresses of all the hosts (master and the node hosts). In my case these were `10.0.0.5, 10.0.0.6 10.0.0.7, 10.0.0.8, 10.0.0.9 and 10.0.0.10`

* Update the `openshifthostprep.yml` file to point the variable `docker_storage_mount` to where ever your extra-storage was mounted. In my case, it was `/dev/sdc`. You can find this by running `fdisk -l`

* Run the playbook to prepare the hosts.  

```
ansible-playbook -i hosts.openshiftprep openshifthostprep.yml
```

**Configure storage server**

Edit the hosts.storage file to include the master's hostname/ip and run the playbook that configures storage

```
ansible-playbook -i hosts.storage configure-storage.yml 
```

### Add DNS entries

If you have an external DNS server, make the 

*  A record entries for the master url to point to the IP address of the host
*  Wild card DNS entry/entries to point to the hosts where Router would run

```
A	master.devday	40.112.62.165	1 Hour	Edit
A	*.apps.devday	40.112.62.166	1 Hour	Edit
A	*.apps.devday	40.112.62.167	1 Hour	Edit
```


### Run OpenShift Installer

Edit /etc/ansible/hosts file
* This config is for installing master, infra-nodes and nodes
* Router, Registry and Metrics will be installed automatically
* It also sets up a server as NFS server. This is where we configured extra storage as `/exports`. This playbook will create PVs for registry and metrics and uses them as storage
* Deploys redundant registry and router 

```
# Create an OSEv3 group that contains the masters and nodes groups
[OSEv3:children]
masters
nodes
nfs

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
# SSH user, this user should allow ssh based auth without requiring a password
ansible_ssh_user=veer

# If ansible_ssh_user is not root, ansible_sudo must be set to true
ansible_sudo=true
ansible_become=yes

# To deploy origin, change deployment_type to origin
deployment_type=openshift-enterprise

openshift_master_default_subdomain=apps.devday.ocpcloud.com
osm_default_node_selector="region=primary"
openshift_hosted_router_selector='region=infra,zone=router'
openshift_registry_selector='region=infra'
openshift_master_api_port=443
openshift_master_console_port=443

openshift_hosted_registry_storage_nfs_directory=/exports


# Metrics
openshift_hosted_metrics_deploy=true
openshift_hosted_metrics_storage_kind=nfs
openshift_hosted_metrics_storage_access_modes=['ReadWriteOnce']
openshift_hosted_metrics_storage_nfs_directory=/exports
openshift_hosted_metrics_storage_nfs_options='*(rw,root_squash)'
openshift_hosted_metrics_storage_volume_name=metrics
openshift_hosted_metrics_storage_volume_size=10Gi


# enable htpasswd authentication
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/openshift/openshift-passwd'}]

# host group for masters
[masters]
10.0.0.5

[nfs]
10.0.0.5

# host group for nodes, includes region info
[nodes]
10.0.0.5 openshift_node_labels="{'region': 'infra', 'zone': 'default'}"  openshift_scheduleable=false openshift_public_hostname=master.devday.ocpcloud.com
10.0.0.6 openshift_node_labels="{'region': 'infra', 'zone': 'router'}" openshift_schedulable=True
10.0.0.7 openshift_node_labels="{'region': 'infra', 'zone': 'router'}" openshift_schedulable=True
10.0.0.8 openshift_node_labels="{'region': 'primary', 'zone': 'east'}" 
10.0.0.9 openshift_node_labels="{'region': 'primary', 'zone': 'west'}" 
10.0.0.10 openshift_node_labels="{'region': 'primary', 'zone': 'east'}"

```

Now run the OpenShift ansible installer

```
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml
```

Note that registry, router and metrics will all be installed. 

### Add Users
Once OpenShift is installed add users

```
touch /etc/openshift/openshift-passwd
htpasswd /etc/openshift/openshift-passwd <<uname>>

``` 

### Post Installation
In OCP 3.3 there are certain tech preview features. Pipelines is one of them and is not enabled by default. Following steps will enable the same. I believe this will be temporary step until the tech preview becomes supported.

* Ensure master host is listed in `hosts.master`
* Run the post-install script that will enable pipelines feature

```
ansible-playbook -i hosts.master post-install.yml
```

###Reset Nodes

If you ever want to clean up docker storage and reset the node(s):

1. Update the `hosts.nodereset` file to include the list of hosts to reset.

2. Run the playbook to reset the node
```
$ ansible-playbook -i hosts.nodereset node-reset.yml
```

