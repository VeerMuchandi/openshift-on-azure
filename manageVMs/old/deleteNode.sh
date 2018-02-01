#!/bin/bash
echo $resourceGroupName
echo $nicName
echo $vmName
azure vm delete --resource-group $resourceGroupName \
    --name $vmName -q

azure network nic delete --name $nicName \
    --resource-group $resourceGroupName -q

