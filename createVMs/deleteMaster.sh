#!/bin/bash
echo $resourceGroupName
echo $nicName
echo $vmName
echo $publicIPName
azure vm delete --resource-group $resourceGroupName \
    --name $vmName -q

azure network nic delete --name $nicName \
    --resource-group $resourceGroupName -q

azure network public-ip delete --name $publicIPName \
 --resource-group $resourceGroupName -q
