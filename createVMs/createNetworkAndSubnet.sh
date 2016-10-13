azure network vnet create --resource-group $resourceGroupName \
--name $vnetName \
--location $location

azure network vnet subnet create --resource-group $resourceGroupName \
    --vnet-name $vnetName \
    --address-prefix $subnetAddressPrefix \
    --name $subnetName 
