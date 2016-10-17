## Managing Master and Node Hosts

#### Adding Masters and Nodes

We will now create the Master and Node Hosts on Azure from the Jump Server. We will be able to log onto these boxes and do installation from the Jump Server.

There are two scripts that do host creation. 

* createMasterHost.sh is used for creating the hosts that require PublicIPs. We will use PublicIPs only for the master(s) and infra-node(s). The script creates a PublicIP, NIC and a VM. It also attaches an extra 30Gbn storage to the VM which we will use to create docker thinpool. The content of this script is as under:

```
cat createMasterHost.sh 
#!/bin/bash
azure network public-ip create --resource-group $resourceGroupName \
    --name $publicIPName \
    --location $location \
    --allocation-method Static

azure network nic create --name $nicName \
    --resource-group $resourceGroupName \
    --location $location \
    --subnet-id $subnetId \
    --network-security-group-name $networkSecurityGroup \
    --public-ip-name $publicIPName  

azure vm create --resource-group $resourceGroupName \
    --name $vmName \
    --location $location \
    --vm-size $vmSize \
    --subnet-id $subnetId \
    --nic-names $nicName \
    --os-type linux \
    --image-urn RHEL \
    --storage-account-name $storageAccountName \
    --admin-username $adminUserName \
    --ssh-publickey-file ~/.ssh/id_rsa.pub

azure vm disk attach-new $resourceGroupName $vmName 30

```

* createNodeHost.sh script is used for application nodes where we don't use PublicIPs. The script creates NIC and a VM. It also attaches 30GB storage for docker thinpool. Here is how the script looks like

```
cat createNodeHost.sh 
#!/bin/bash
azure network nic create --name $nicName \
    --resource-group $resourceGroupName \
    --location $location \
    --subnet-id $subnetId  	             


azure vm create --resource-group $resourceGroupName \
    --name $vmName \
    --location $location \
    --vm-size $vmSize \
    --subnet-id $subnetId \
    --nic-names $nicName \
    --os-type linux \
    --image-urn RHEL \
    --storage-account-name $storageAccountName \
    --admin-username $adminUserName \
    --ssh-publickey-file ~/.ssh/id_rsa.pub
    
azure vm disk attach-new $resourceGroupName $vmName 30
```

**Important** The above two scripts are called from the script `addAzureHosts.sh`. Open this script and edit the list of hosts to add. Change the environment variables to your values. 

**CAUTION** Be conservative about the size of the hostname. The overall hostname should be no more than 63 chars and a major portion of it will be used by Azure. Service will throw this error during installation if you don't abide
```
Oct 13 17:45:31 devday-master atomic-openshift-node[92756]: E1013 17:45:31.234652   92756 kubelet.go:1200] Unable to register node "devday-master.igyiwpfqdeaepnzehgzpbz3i4a.xx.internal.cloudapp.net" with API server: Node "devday-master.igyiwpfqdeaepnzehgzpbz3i4a.xx.internal.cloudapp.net" is invalid: metadata.labels: Invalid value: "devday-master.igyiwpfqdeaepnzehgzpbz3i4a.xx.internal.cloudapp.net": must be no more than 63 characters
```


**Note** that I have followed a pattern (eg: used devday in every NIC name) to assign NIC names so that they are searchable later. It is a matter of convenience that will be useful using search pattern. 

Run the host addition script

```
source ./addAzureHosts.sh
```

#### Get IP address to use

Get the list of private IP addresses for the hosts. Since I used a pattern "devday" in every NIC name, it is useful for me in this search. Make a note of these IP address. 

```
# for i in $(azure network nic list | grep devday | awk '{print $2}');do echo $i; azure network nic show $i --resource-group $resourceGroupName| grep "Private IP address"; done
devdayInfraNode1NIC
data:      Private IP address            : 10.0.0.6
devdayInfraNode2NIC
data:      Private IP address            : 10.0.0.7
devdayMasterNIC
data:      Private IP address            : 10.0.0.5
devdayNode1NIC
data:      Private IP address            : 10.0.0.8
devdayNode2NIC
data:      Private IP address            : 10.0.0.9
devdayNode3NIC
data:      Private IP address            : 10.0.0.10
```

Verify that you can login to each of these hosts from the jump server 
```
ssh <<youradminuser>>@10.0.0.5
```

Get a list of public IP addresses by running this command. You will need these values to make your DNS entries.

```
azure vm list-ip-address --resource-group $resourceGroupName 
```

Change to v3.3 folder as you have a sample hosts file and ansible playbooks there.

```
cd ../v3.3
```

### Stopping your VMs
Use these steps to stop your VMs when they are not in use to conserve resources.

**Note** This script assumes that I am using a pattern "dd-" on the hostname of every machine on my cluster. Change your pattern according to what you are using.

```
for i in $(azure vm list --resource-group $resourceGroupName | grep dd- | awk '{print $3}'); \
do azure vm stop --resource-group $resourceGroupName $i; done

for i in $(azure vm list --resource-group $resourceGroupName | grep dd- | awk '{print $3}'); \
do azure vm deallocate --resource-group $resourceGroupName $i; done

```

### Starting your VMs

**Note** This script assumes that I am using a pattern "dd-" on the hostname of every machine on my cluster. Change your pattern according to what you are using.

```
for i in $(azure vm list --resource-group $resourceGroupName | grep dd- | awk '{print $3}'); \
do azure vm start --resource-group $resourceGroupName $i; done

```


### Deleting your VMs

**Use this only when you want to cleanup your environment and release resources**

If you are deleting master or infra-nodes that use a PublicIP, do the following.

* Set the relevant environment variables.. as an example

```
publicIPName="devdayInfraNode1PublicIP"
nicName="devdayInfraNode1NIC"
vmName="devday-infranode1"
vmSize="Standard_DS2"
``` 

* Run the delete master script

```
source ./deleteMaster.sh
```


If you are delete a node that where we did not configure a PublicIP, do the following.

* Set the relevant environment variables.. as an example

```
nicName="devdayNode1NIC"
vmName="devday-node1"
vmSize="Standard_DS12_V2"
``` 

* Run the delete master script

```
source ./deleteNode.sh
```

Or if you want to delete all the hosts, then copy the `addAzureHosts.sh` that you used before into a new name `deleteAzureHosts.sh` and replace 
* `createMasterHost.sh` with `deleteMaster.sh`
* `createNodeHost.sh` with `deleteNode.sh`

Remove all disk attach commands

and run

```
source deleteAzureHosts.sh
``` 
