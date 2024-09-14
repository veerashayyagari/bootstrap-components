#!/bin/bash

# Use azcli to setup a VM with NVIDIA GPU
#
#

set -u
set -e

az login --use-device-code

subscription_id=$(az account show --query id -o tsv)

# if subscription_id is empty, then the user is not logged in throw an error
if [ -z "$subscription_id" ]; then
    echo "No default subscription id found. Are you logged in ? Please login to continue."
    exit 1
fi

read -p "Enter the deployment region (default: centralus): " deploymentRegion
deploymentRegion=${deploymentRegion:-centralus}

echo "Select the GPU type:"
echo "1. NVIDIA A100"
echo "2. NVIDIA H100"
read -p "Enter the number corresponding to the GPU type (default is 1): " gpuOption
case $gpuOption in
    1)
        gpuType="a100"
        ;;
    2)
        gpuType="h100"
        ;;
    *)
        echo "Invalid option. Using default GPU type: NVIDIA A100"
        gpuType="a100"
        ;;
esac

# if gpuType is a100, then the sku is Standard_NC24ads_A100_v4 or Standard_NC48ads_A100_v4 or Standard_NC96ads_A100_v4, give the options and ask user to select one
if [ "$gpuType" == "a100" ]; then
    echo "Select the SKU for the VM:"
    echo "1. Standard_NC24ads_A100_v4"
    echo "2. Standard_NC48ads_A100_v4"
    echo "3. Standard_NC96ads_A100_v4"
    read -p "Enter the number corresponding to the SKU (default is 1): " skuOption
    case $skuOption in
        1)
            sku="Standard_NC24ads_A100_v4"
            requestedQuota=24
            family="Standard NCADS_A100_v4 Family vCPUs"
            ;;
        2)
            sku="Standard_NC48ads_A100_v4"
            requestedQuota=48
            family="Standard NCADS_A100_v4 Family vCPUs"
            ;;
        3)
            sku="Standard_NC96ads_A100_v4"
            requestedQuota=96
            family="Standard NCADS_A100_v4 Family vCPUs"
            ;;
        *)
            echo "Invalid option. Using default SKU: Standard_NC24ads_A100_v4"
            sku="Standard_NC24ads_A100_v4"
            requestedQuota=24
            family="Standard NCADS_A100_v4 Family vCPUs"
            ;;
    esac
fi

# if gpuType is h100, then the sku is Standard_NC40ads_H100_v5 or Standard_NC80adis_H100_v5, give the options and ask user to select one
if [ "$gpuType" == "h100" ]; then
    echo "Select the SKU for the VM:"
    echo "1. Standard_NC40ads_H100_v5"
    echo "2. Standard_NC80adis_H100_v5"
    read -p "Enter the number corresponding to the SKU (default is 1): " skuOption
    case $skuOption in
        1)
            sku="Standard_NC40ads_H100_v5"
            requestedQuota=40
            family="Standard NCadsH100v5 Family vCPUs"
            ;;
        2)
            sku="Standard_NC80adis_H100_v5"
            requestedQuota=80
            family="Standard NCadsH100v5 Family vCPUs"
            ;;
        *)
            echo "Invalid option. Using default SKU: Standard_NC40ads_H100_v5"
            sku="Standard_NC40ads_H100_v5"
            requestedQuota=40
            family="Standard NCadsH100v5 Family vCPUs"
            ;;
    esac
fi



read -p "Enter the name of the resource group (default: az-$deploymentRegion-$gpuType-gpu-vm-rg): " resourceGroupName
resourceGroupName=${resourceGroupName:-az-$deploymentRegion-$gpuType-gpu-vm-rg}

read -p "Enter the name of the virtual machine (default: az-$deploymentRegion-$gpuType-gpu-vm): " vmName
vmName=${vmName:-az-$deploymentRegion-$gpuType-gpu-vm}

# ask for vm username
read -p "Enter the username for the VM (default: azureuser): " vmUsername
vmUsername=${vmUsername:-azureuser}

# ask for vm ssh public key location
read -p "Enter the path to the SSH public key file (default: ~/.ssh/id_rsa.pub): " sshPublicKeyPath
sshPublicKey=${sshPublicKeyPath:-~/.ssh/id_rsa.pub}
sshPublicKeyPath=$(eval echo $sshPublicKeyPath)
sshPublicKey=$(cat "$sshPublicKeyPath")

# ask if the user wants to use spot discount
read -p "Do you want to use spot discount. Y or yes and N for no (default: Y): " useSpotDiscount
useSpotDiscount=${useSpotDiscount:-Y}

# make useSpotDiscount uppercase and check if it's a valid option
useSpotDiscount=$(echo $useSpotDiscount | tr '[:lower:]' '[:upper:]')
if [ "$useSpotDiscount" != "Y" ] && [ "$useSpotDiscount" != "N" ]; then
    echo "Invalid option for spot discount. Please enter Y or N"
    exit 1
fi

if [ "$useSpotDiscount" == "N" ]; then
    quota=$(az vm list-usage --location $deploymentRegion --query "[?localName=='$family'].{currentValue:currentValue, limit:limit}" -o json)
    currentValue=$(echo $quota | jq -r '.[0].currentValue')
    limit=$(echo $quota | jq -r '.[0].limit')
    priority="Regular"
    
    if [ -z "$currentValue" ] || [ -z "$limit" ]; then
        echo "The SKU $sku is not available in the region $deploymentRegion. Please select a different SKU or region."
        exit 1
    fi
    
    if [ "$currentValue" -ge "$requestedQuota" ]; then
        echo "The SKU $sku has reached the quota limit in the region $deploymentRegion. Please select a different SKU or region."
        exit 1
    fi
else
    read currentValue limit <<< $(az vm list-usage --location $deploymentRegion --query "[?contains(localName, 'Low-priority')].[currentValue, limit]" -o tsv)
    
    if [ -z "$currentValue" ] || [ -z "$limit" ]; then
        echo "The SKU $sku is not available in the region $deploymentRegion for Spot deployment. Please select a different SKU or region."
        exit 1
    fi
    
    if [ "$currentValue" -ge "$requestedQuota" ]; then
        echo "The SKU $sku has reached the quota limit in the region $deploymentRegion for Spot deployment. Please select a different SKU or region."
        exit 1
    fi

    priority="Spot"
fi

# create the resource group if not exists
az group create --name $resourceGroupName --location $deploymentRegion

# create an nsg in the resource group
az network nsg create \
--resource-group $resourceGroupName \
--location $deploymentRegion \
--name ${vmName}-nsg

# my public ip
my_ip=$(curl -s ifconfig.me)

# allow ssh from my ip
az network nsg rule create \
--resource-group $resourceGroupName \
--nsg-name ${vmName}-nsg \
--name allow-ssh \
--priority 100 \
--source-address-prefixes $my_ip \
--source-port-ranges '*' \
--destination-port-ranges 22 \
--access Allow \
--protocol Tcp \
--description "Allow SSH from my IP"

# create a public ip in the resource group
az network public-ip create \
--resource-group $resourceGroupName \
--location $deploymentRegion \
--name ${vmName}-public-ip \
--sku Standard \
--allocation-method Static \
--dns-name ${vmName}

# create a vnet in the resource group with default subnet
az network vnet create \
--resource-group $resourceGroupName \
--location $deploymentRegion \
--name ${vmName}-vnet \
--address-prefixes 10.0.0.0/24 \
--subnet-name default \
--subnet-prefixes 10.0.0.0/26

# create a nic in the resource group
az network nic create \
--resource-group $resourceGroupName \
--location $deploymentRegion \
--name ${vmName}-nic \
--vnet-name ${vmName}-vnet \
--subnet default \
--network-security-group ${vmName}-nsg \
--public-ip-address ${vmName}-public-ip

# create the vm
az vm create \
--resource-group $resourceGroupName \
--location $deploymentRegion \
--name $vmName \
--image Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest \
--size $sku \
--nics ${vmName}-nic \
--admin-username $vmUsername \
--ssh-key-value $sshPublicKeyPath \
--nic-delete-option Delete \
--os-disk-size-gb 128 \
--os-disk-delete-option Delete \
--priority $priority \
--security-type Standard

# enable auto-shutdown at 8 PM PST
az vm auto-shutdown \
--resource-group $resourceGroupName \
--name $vmName \
--time 04:00

# wait till the vm is created
while true; do
    provisioningState=$(az vm show --resource-group $resourceGroupName --name $vmName --query provisioningState -o tsv)
    if [ "$provisioningState" == "Succeeded" ]; then
        break
    fi
    sleep 10
done

# enable nvidia gpu driver extension
az vm extension set \
--resource-group $resourceGroupName \
--vm-name $vmName \
--name NvidiaGpuDriverLinux \
--publisher Microsoft.HpcCompute \
--version 1.9

# wait till the extension status is provisioned
while true; do
    provisionStatus=$(az vm extension show --resource-group $resourceGroupName --vm-name $vmName --name NvidiaGpuDriverLinux --query provisioningState -o tsv)
    if [ "$provisionStatus" == "Succeeded" ]; then
        break
    fi
    sleep 10
done

# reboot the vm
az vm restart --resource-group $resourceGroupName --name $vmName

# print ssh command using dns name, username and sshkey
echo "SSH into the VM using the following command:"
sshCommand="ssh $vmUsername@${vmName}.${deploymentRegion}.cloudapp.azure.com -i ${sshPublicKeyPath%.pub}"
echo $sshCommand

# execute any custom script inside the vm
# remoteScriptPath="/path/to/remote/script.sh"
# $sshCommand "bash -s" < $remoteScriptPath

# clean up once the work is done
# az group delete --name $resourceGroupName --yes