# Installing up OpenShift on Azure 

## Set up ansible on the Master Host

We will use master as our jump host to install OpenShift using Ansible. 
 
*  Log into the master
* `sudo bash` to become root
*  Subscribe to RedHat Network

```
# subscription-manager register
Registering to: subscription.rhsm.redhat.com:443/subscription
Username: <<your RH UserName>>
Password: <<your RH Password>>
```
* Find PoolID that has OpenShift Subscription

```
# subscription-manager list --available --matches '*OpenShift*'
```

* Attach Pool

```
# subscription-manager attach --pool <<your poolid>> 
```
* Enable required repos and disable the rest

```
# subscription-manager repos --disable="*"
# subscription-manager repos \
    --enable="rhel-7-server-rpms" \
    --enable="rhel-7-server-extras-rpms" \
    --enable="rhel-7-server-ose-3.7-rpms" \
    --enable="rhel-7-fast-datapath-rpms"
```

* Install `atomic-openshift-utils` and this will install ansible

```
 # yum install -y atomic-openshift-utils
```

* Generate SSH Keys

```
# ssh-keygen
```	

* Use this key (`cat ~/.ssh/id_rsa.pub` as the login key for the other hosts. 
Login into each host using the admin-username and the private ip
`ssh user01@10.0.0.5` and the password defined as admin-password. Become root `sudo bash` and add the copied id_rsa.pub to file `/root/.ssh/authorized_keys`. Copy the key to `/root/.ssh/authorized_keys` file on the master as well to self ssh without password.

	Now you should be able to ssh from master host to the other (node) hosts as root without password. Verify that you are able to ssh to each host including master using privateIP. Example `ssh 10.0.0.4`

* Install git
```yum install git -y ```


* `git clone` the repository (https://github.com/VeerMuchandi/openshift-on-azure) onto the master host. For now using context-dir v3.7. You should now get the required ansible playbooks to prep the hosts

### Prepare the Hosts

* Update the `hosts.openshiftprep` file with the internal ip addresses of all the hosts (master and the node hosts). In my case these were `10.0.0.4, 10.0.0.5 10.0.0.6 10.0.0.7`

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
A	master.opsday	40.112.62.165	1 Hour	Edit
A	*.apps.opsday	40.112.62.165	1 Hour	Edit
```


### Run OpenShift Installer

Edit /etc/ansible/hosts file
* This config is for installing master, infra-nodes and nodes
* Router, Registry and Metrics will be installed automatically
* It also sets up a server as NFS server. This is where we configured extra storage as `/exports`. This playbook will create PVs for registry and metrics and uses them as storage
* Deploys redundant registry and router 

```
# cat /etc/ansible/hosts
# Create an OSEv3 group that contains the masters and nodes groups
[OSEv3:children]
masters
nodes
nfs
etcd

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
# SSH user, this user should allow ssh based auth without requiring a password
ansible_ssh_user=root

# If ansible_ssh_user is not root, ansible_sudo must be set to true
#ansible_sudo=true
#ansible_become=yes

# To deploy origin, change deployment_type to origin
deployment_type=openshift-enterprise

openshift_clock_enabled=true

# Disabling for smaller instances used for Demo purposes. Use instances with minimum disk and memory sizes required by OpenShift
openshift_disable_check=disk_availability,memory_availability

#Enable network policy plugin. This is currently Tech Preview
os_sdn_network_plugin_name='redhat/openshift-ovs-networkpolicy'

openshift_master_default_subdomain=apps.opsday.ocpcloud.com
osm_default_node_selector="region=primary"
openshift_router_selector='region=infra,zone=router'
openshift_registry_selector='region=infra'

## The two parameters below would be used if you want API Server and Master running on 443 instead of 8443. 
## In this cluster 443 is used by router, so we cannot use 443 for master
#openshift_master_api_port=443
#openshift_master_console_port=443


openshift_hosted_registry_storage_nfs_directory=/exports


# Metrics
openshift_metrics_install_metrics=true
openshift_metrics_storage_kind=nfs
openshift_metrics_storage_access_modes=['ReadWriteOnce']
openshift_metrics_storage_nfs_directory=/exports
openshift_metrics_storage_nfs_options='*(rw,root_squash)'
openshift_metrics_storage_volume_name=metrics
openshift_metrics_storage_volume_size=10Gi
openshift_metrics_storage_labels={'storage': 'metrics'}
openshift_master_metrics_public_url=https://hawkular-metrics.apps.opsday.ocpcloud.com/hawkular/metrics

# Logging
openshift_logging_install_logging=true
openshift_logging_storage_kind=nfs
openshift_logging_storage_access_modes=['ReadWriteOnce']
openshift_logging_storage_nfs_directory=/exports
openshift_logging_storage_nfs_options='*(rw,root_squash)'
openshift_logging_storage_volume_name=logging
openshift_logging_storage_volume_size=10Gi
openshift_logging_storage_labels={'storage': 'logging'}
openshift_master_logging_public_url=https://kibana.apps.opsday.ocpcloud.com

# Registry
openshift_hosted_registry_storage_kind=nfs
openshift_hosted_registry_storage_access_modes=['ReadWriteMany']
openshift_hosted_registry_storage_nfs_directory=/exports
openshift_hosted_registry_storage_nfs_options='*(rw,root_squash)'
openshift_hosted_registry_storage_volume_name=registry
openshift_hosted_registry_storage_volume_size=10Gi

# OAB etcd storage configuration
openshift_hosted_etcd_storage_kind=nfs
openshift_hosted_etcd_storage_nfs_options="*(rw,root_squash,sync,no_wdelay)"
openshift_hosted_etcd_storage_nfs_directory=/exports
openshift_hosted_etcd_storage_volume_name=etcd-vol2 
openshift_hosted_etcd_storage_access_modes=["ReadWriteOnce"]
openshift_hosted_etcd_storage_volume_size=1G
openshift_hosted_etcd_storage_labels={'storage': 'etcd'}

# template service broker
openshift_template_service_broker_namespaces=['openshift','my-templates']

# enable htpasswd authentication
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/openshift/openshift-passwd'}]

# host group for masters
[masters]
10.0.0.4 

[nfs]
10.0.0.4 

[etcd]
10.0.0.4

# host group for nodes, includes region info
[nodes]
10.0.0.4 openshift_hostname=10.0.0.4 openshift_node_labels="{'region': 'infra', 'zone': 'router'}"  openshift_scheduleable=true openshift_public_hostname=master.opsday.ocpcloud.com 
10.0.0.5 openshift_hostname=10.0.0.5 openshift_node_labels="{'region': 'primary', 'zone': 'east'}" 
10.0.0.6 openshift_hostname=10.0.0.6 openshift_node_labels="{'region': 'primary', 'zone': 'west'}" 
10.0.0.7 openshift_hostname=10.0.0.7 openshift_node_labels="{'region': 'primary', 'zone': 'central'}" 
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

