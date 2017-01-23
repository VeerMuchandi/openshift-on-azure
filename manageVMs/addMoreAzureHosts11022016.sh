#!/bin/bash

location="westus2"
resourceGroupName="openshift-workshop"
vnetName="openshift-workshop-westus2-vnet"
subnetName="default"
subnetAddressPrefix="10.0.0.0/24"
networkSecurityGroup="master-workshop-westus2"
storageAccountName="openshiftwkshpwestus2"
adminUserName="veer"

# Find subnetId
subnetId="$(azure network vnet subnet show --resource-group $resourceGroupName \
                --vnet-name $vnetName \
                --name $subnetName|grep Id)"
subnetId=${subnetId#*/}  

echo "subnetId: $subnetId"

#Add AppNode4
nicName="devdayNode4NIC"
vmName="dd-node4"
vmSize="Standard_DS12_V2"
echo "Adding $vmName"

source ./createNodeHost.sh


azure vm list --resource-group $resourceGroupName








