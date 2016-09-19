# Setting up OpenShift on Azure - my notes
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
 subscription-manager repos     --enable="rhel-7-server-rpms"     --enable="rhel-7-server-extras-rpms"     --enable="rhel-7-server-ose-3.2-rpms"
 yum install -y atomic-openshift-utils
```

* Switch back to regular user

	```
	ssh-keygen
	```	

* Use this key (`cat ~/.ssh/id_rsa.pub` as the login key for the other hosts. Configure this from Azure console  Node->Support+Troubleshooting->Reset Password

	Now you should be able to ssh from master host to the other (node) hosts.

* `git clone` the repository (https://github.com/VeerMuchandi/openshift-on-azure) onto the master host. For now using context-dir v3.2. You should now get the required ansible playbooks to prep the hosts

* Update the `hosts.openshiftprep` file with the internal ip addresses of all the hosts (master and the node hosts). In my case these were `10.0.0.4, 10.0.0.5 and 10.0.0.6`

* Update the `openshifthostprep.yml` file to point the variable `docker_storage_mount` to where ever your extra-storage was mounted. In my case, it was `/dev/sdc`. You can find this by running `fdisk -l`

* Run the playbook to prepare the hosts.  

```
ansible-playbook -i hosts.openshiftprep openshifthostprep.yml
```

Configure registry storage

Edit the hosts.registrystorage file to include the master's hostname/ip and run the playbook that configures registry storage

```
ansible-playbook -i hosts.registrystorage install-registry-storage.yml 
```

**DNS**

If you have an external DNS server, make the 

*  A record entries for the master url to point to the IP address of the host
*  wild card DNS entry

```
A	master.devday	40.112.62.165	1 Hour	Edit
A	*.apps.devday	40.112.62.165	1 Hour	Edit
```


Edit /etc/ansible/hosts file

```
# cat /etc/ansible/hosts
# Create an OSEv3 group that contains the masters and nodes groups
[OSEv3:children]
masters
nodes

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
# SSH user, this user should allow ssh based auth without requiring a password
ansible_ssh_user=root

# If ansible_ssh_user is not root, ansible_sudo must be set to true
#ansible_sudo=true

# To deploy origin, change deployment_type to origin
deployment_type=openshift-enterprise

osm_default_subdomain=apps.devday.ocpcloud.com
osm_default_node_selector="region=primary"
openshift_router_selector='region=infra'
openshift_registry_selector='region=infra'
#openshift_master_api_port=443
#openshift_master_console_port=443


# enable htpasswd authentication
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/openshift/openshift-passwd'}]

# host group for masters
[masters]
10.0.0.4

# host group for nodes, includes region info
[nodes]
10.0.0.4 openshift_node_labels="{'region': 'infra', 'zone': 'default'}"  openshift_scheduleable=true openshift_public_hostname=master.devday.ocpcloud.com
#inode1-devday.eastus.cloudapp.azure.com openshift_node_labels="{'region': 'infra', 'zone': 'router'}"
10.0.0.5 openshift_node_labels="{'region': 'primary', 'zone': 'east'}" 
10.0.0.6 openshift_node_labels="{'region': 'primary', 'zone': 'west'}"
```

Now run the OpenShift ansible installer

```
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml
```

Once OpenShift is installed add users

```
touch /etc/openshift/openshift-passwd
htpasswd /etc/openshift/openshift-passwd <<uname>>

``` 

####Reset Nodes

If you ever want to clean up docker storage and reset the node(s):

1. Update the `hosts.nodereset` file to include the list of hosts to reset.

2. Run the playbook to reset the node
```
$ ansible-playbook -i hosts.nodereset node-reset.yml
```

