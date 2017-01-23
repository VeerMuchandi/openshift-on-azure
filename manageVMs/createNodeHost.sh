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
    
azure vm disk attach-new $resourceGroupName $vmName 128
