## Spinning up servers on Azure

**Assumptions**
You have an account with Azure
You have a resource group already created.
You have installed Azure CLI on you localhost. We will first create a jumpserver on Azure and do rest of the installation from that jumpserver.

### Setting up Jump Server

#### Set Environment Variables
On the local workstation, set the following environment variables.

Use your own values here - 

```
location="westus2"
resourceGroupName="openshift-workshop"
vnetName="openshift-workshop-westus2-vnet"
subnetName="default"
subnetAddressPrefix="10.0.0.0/24"
networkSecurityGroup="master-workshop-westus2"
storageAccountName="openshiftwkshpwestus2"
adminUserName="<<yourusername>>"
```

#### Create Network Security Group

Run the following script to create the Network Security Group. This has the firewall rules that you would apply to masters. This is a one time task.

```
source ./createNetworkSecurityGroup.sh
```

The script has the following commands

```
$ cat createNetworkSecurityGroup.sh 
azure network nsg create --resource-group $resourceGroupName \
      --name $networkSecurityGroup \
      --location $location

azure network nsg rule create --resource-group $resourceGroupName \
    --nsg-name $networkSecurityGroup \
    --name allow-https \
    --description "Allow access to port 443 for HTTPS" \
    --protocol Tcp \
    --source-address-prefix \* \
    --source-port-range \* \
    --destination-address-prefix \* \
    --destination-port-range 443 \
    --access Allow \
    --priority 102 \
    --direction Inbound
azure network nsg rule create --resource-group $resourceGroupName \
    --nsg-name $networkSecurityGroup \
    --name allow-http \
    --description "Allow access to port 80 for HTTP" \
    --protocol Tcp \
    --source-address-prefix \* \
    --source-port-range \* \
    --destination-address-prefix \* \
    --destination-port-range 80 \
    --access Allow \
    --priority 112 \
    --direction Inbound
azure network nsg rule create --resource-group $resourceGroupName \
    --nsg-name $networkSecurityGroup \
    --name allow-master-api \
    --description "Allow access to port 8443" \
    --protocol Tcp \
    --source-address-prefix \* \
    --source-port-range \* \
    --destination-address-prefix \* \
    --destination-port-range 8443 \
    --access Allow \
    --priority 122 \
    --direction Inbound
azure network nsg rule create --resource-group $resourceGroupName \
    --nsg-name $networkSecurityGroup \
    --name allow-etcd \
    --description "Allow access to port 2379" \
    --protocol Tcp \
    --source-address-prefix \* \
    --source-port-range \* \
    --destination-address-prefix \* \
    --destination-port-range 2379 \
    --access Allow \
    --priority 132 \
    --direction Inbound
azure network nsg rule create --resource-group $resourceGroupName \
    --nsg-name $networkSecurityGroup \
    --name allow-cockpit \
    --description "Allow access to port 9090" \
    --protocol Tcp \
    --source-address-prefix \* \
    --source-port-range \* \
    --destination-address-prefix \* \
    --destination-port-range 9090 \
    --access Allow \
    --priority 142 \
    --direction Inbound
azure network nsg rule create --resource-group $resourceGroupName \
    --nsg-name $networkSecurityGroup \
    --name default-allow-ssh \
    --description "Allow access to port 22" \
    --protocol Tcp \
    --source-address-prefix \* \
    --source-port-range \* \
    --destination-address-prefix \* \
    --destination-port-range 22 \
    --access Allow \
    --priority 152 \
    --direction Inbound
    
```

You can verify the rules by running

```
azure network nsg show --resource-group $resourceGroupName \
      --name $networkSecurityGroup
```

#### Create a Storage Account
This is a one time task. If you already have one, skip this step.

```
azure storage account create $storageAccountName --resource-group $resourceGroupName --sku-name PLRS --kind Storage --location $location
```

Verify by running

```
azure storage account show $storageAccountName --resource-group $resourceGroupName
```

#### Create Network and Subnet

This is a one time task. If you already have these, you don't have to create them again.

```
source ./createNetworkAndSubnet.sh
```

The contents of this script are
```
azure network vnet create --resource-group $resourceGroupName \
--name $vnetName \
--location $location

azure network vnet subnet create --resource-group $resourceGroupName \
    --vnet-name $vnetName \
    --address-prefix $subnetAddressPrefix \
    --name $subnetName 
```

#### Find your Subnet Id

Run the following commands to get the subnetId assigned to the environment variable.

```
subnetId="$(azure network vnet subnet show --resource-group $resourceGroupName \
                --vnet-name $vnetName \
                --name $subnetName|grep Id)"
subnetId=${subnetId#*/}  
```

Verify that you have a value similar to

```
$ echo $subnetId
subscriptions/b733b6a9-e6c9-43f6-8bfc-102d1379a9ea/resourceGroups/openshift-workshop/providers/Microsoft.Network/virtualNetworks/openshift-workshop-westus2-vnet/subnets/default
```


#### Create a Jump Server

Set environment variables for your Jump Server. Use your own values for these variables.

```
publicIPName="veerJumpServerIP"
nicName="veerJumpServerNIC"
vmName="veer-jump-server"
vmSize="Standard_DS1_V2"
```

Create a PublicIP, NIC and a VM that we will use as a Jump Server.

**Note** we are using the public key from the workstation as the ssh-key to login. So you can ssh using the ip address and the admin username from your workstation to the jumpserver.

```
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

```

Find your jump server's public ip by running
```
azure network public-ip show --name $publicIPName --resource-group $resourceGroupName
```

Now you can login to the jump server using

```
ssh <<youradminusername>>@<<jumpserverip>>
sudo bash
```

#### Prepare your Jump Server

Run the following commands to install Azure CLI on the jump server. These will install NPM and then use that to install azure-cli.

```
# yum install -y gcc-c++ make
# curl -sL https://rpm.nodesource.com/setup_6.x | sudo -E bash -
# yum install nodejs
# node -v
# npm -v  
# npm install -g azure-cli
```

Verify by running

```
# azure help
```

Now run the following command to login and follow the instructions to enter the code in the browser

```
# azure login
info:    Executing command login
- Authenticating...info:    To sign in, use a web browser to open the page https://aka.ms/devicelogin. Enter the code XXXXXXX to authenticate.

```

Once logged in, verify by running and it should show your VMs in your resource group, including this jump server.

```
azure vm list --resource-group $resourceGroupName
```

For the next steps you need OpenShift subscription from RedHat.

Install atomic-openshift-utils

```
subscription-manager register
subscription-manager attach --pool <<your poolid>> 
subscription-manager repos --disable="*"
subscription-manager repos     --enable="rhel-7-server-rpms"     --enable="rhel-7-server-extras-rpms"     --enable="rhel-7-server-ose-3.3-rpms"
yum install -y atomic-openshift-utils

```

Generate SSH Keys. We will use these keys for logging into the OpenShift cluster.

```
ssh-keygen
``` 

Install git

```
yum install git -y
```

git clone the repository (https://github.com/VeerMuchandi/openshift-on-azure) onto the master host. We will be using context-dir v3.3. You should now get the required ansible playbooks to prep the hosts.

```
git clone https://github.com/VeerMuchandi/openshift-on-azure
cd openshift-on-azure/createVMs
```

Now we are ready to spin up VMs for the OpenShift cluster.

