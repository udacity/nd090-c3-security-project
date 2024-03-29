Param([String]$tenantID,
[String]$subscriptionID,
[String]$domainName,
[Parameter(Mandatory=$false)]
[Switch]$usermode)


$resourceGroupName = 'udacity'
$location = 'eastus'
$spnName = 'udacity'

$spnClientId = ""
$spnClientSecret = ""

if($usermode -eq $false)
{
    az login --service-principal -u $spnClientId -p $spnClientSecret -t $tenantID
}
else 
{
    az login
}

az account set --subscription $subscriptionID

 $spn = az ad sp create-for-rbac --name $spnName `
         --role Contributor `
         --scopes /subscriptions/$subscriptionID/resourceGroups/$resourceGroupName `
         --query '{ClientId:appId,ClientSecret:password}' -o json | ConvertFrom-Json
 $spnClientId = $spn.ClientId
 $spnClientSecret = $spn.ClientSecret


Function CreateUsersAndGroups()
{
    $devopsGroup = az ad group create --display-name 'devops' --mail-nickname 'devops' --query '{Id:objectId}' -o json | ConvertFrom-Json
    $secopsGroup = az ad group create --display-name 'secops' --mail-nickname 'secops' --query '{Id:objectId}' -o json | ConvertFrom-Json
    $dbAdminGroup = az ad group create --display-name 'dbadmin' --mail-nickname 'dbadmin' --query '{Id:objectId}' -o json | ConvertFrom-Json

    $username = 'devops@'+$domainName
    Write-Host $username
    $devopsUser = az ad user create --display-name 'Dev Ops' --password 'Pass123!' --user-principal-name $username --query '{Id:objectId}' -o json | ConvertFrom-Json
    az ad group member add --group $devopsGroup.Id --member-id $devopsUser.Id

    $username = 'secops@'+$domainName
    Write-Host $username
    $secopsUser = az ad user create --display-name 'Sec Ops' --password 'Pass123!' --user-principal-name $username --query '{Id:objectId}' -o json | ConvertFrom-Json
    az ad group member add --group $secopsGroup.Id --member-id $secopsUser.Id

    $username = 'dbadmin@'+$domainName
    Write-Host $username
    $dbAdminUser = az ad user create --display-name 'Db Admin' --password 'Pass123!' --user-principal-name $username --query '{Id:objectId}' -o json | ConvertFrom-Json
    az ad group member add --group $dbAdminGroup.Id --member-id $dbAdminUser.Id

    az role assignment create --role "User Access Administrator" --assignee $secopsGroup.Id --subscription $subscriptionID
    az role assignment create --role "Contributor" --assignee $devopsGroup.Id --subscription $subscriptionID
    az role assignment create --role "Reader" --assignee $dbAdminGroup.Id --subscription $subscriptionID
}

$ingressLoadBalancerIpAddress = "10.1.1.100"
$dnsZoneName = "udacity.com"
$aksClusterName = "azsecurity"
$azFirewallName = "azfw"
$adminWorkStationAdminPassword = "azuresecurity123!" #set it at runtime
$sqlServerAdminPassword = "azuresecurity123!" #set it at runtime
$vnetName = "vnet"

Function ToBase64($value) {
    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($value))
}

Function DeployPublicIpAddress($azFirewallName) {
    Write-Host 'Deploying PublicIp'
    $publicIpAddressOutputs = az deployment group create --resource-group $resourceGroupName --template-file ./templates/publicipaddress.json `
                            --parameters firewallName=$azFirewallName --query '{firewallIpAddress:properties.outputs.firewallPublicIpAddress.value, name:properties.outputs.name.value}'

    Write-Host 'Deployed PublicIP'
$publicIpAddressOutputsJson = $publicIpAddressOutputs | ConvertFrom-Json
return $publicIpAddressOutputsJson
}

Function DeployNetwork() {
    Write-Host 'Deploying Network'
    $networkDeploymentOutputs = az deployment group create --resource-group $resourceGroupName --template-file ./templates/network.json `
            --parameters dnsZoneName=$dnsZoneName `
            --query '{vnetName:properties.outputs.vnetName.value, aksSubnetName:properties.outputs.aksSubnetName.value, routeTableName:properties.outputs.routeTableName.value}' 

    Write-Host 'Deployed Network'
    $networkDeploymentOutputsJson = $networkDeploymentOutputs | ConvertFrom-Json
    return $networkDeploymentOutputsJson
}

Function DeployFirewall($azFirewallName, $vnetName, $firewallPublicIpAddressName, $firewallPublicIpAddress) {
    Write-Host 'Deploying Firewall'
    $firewallDeploymentOutputs = az deployment group create --resource-group $resourceGroupName --template-file ./templates/firewall.json `
                                --parameters firewallName=$azFirewallName `
                                --parameters virtualNetworkName=$vnetName `
                                --parameters firewallPublicIpAddressName=$firewallPublicIpAddressName `
                                --parameters ingressControllerIpAddress=$ingressLoadBalancerIpAddress `
                                --parameters firewallPublicIpAddress=$firewallPublicIpAddress `
                                --query '{firewallPrivateIpAddress:properties.outputs.firewallPrivateIPAddress.value}'

    Write-Host 'Deployed Firewall'
    $firewallDeploymentOutputsJson = $firewallDeploymentOutputs | ConvertFrom-Json
    return $firewallDeploymentOutputsJson.firewallPrivateIPAddress

}

Function DeployAdminWorkstation($adminWorkStationAdminPassword, $vnetName) {
    Write-Host 'Deploying AdminWorkstation'
    $outputs = az deployment group create --resource-group $resourceGroupName --template-file ./templates/vm.json `
                            --parameters adminWorkStationPassword=$adminWorkStationAdminPassword `
                            --parameters virtualNetworkName=$vnetName
    Write-Host 'Deployed AdminWorkstation'
}

Function DeployRoutes($routeTableName, $firewallPrivateIPAddress) {
    Write-Host 'Deploying Routes'
    $outputs = az deployment group create --resource-group $resourceGroupName --template-file ./templates/routes.json `
                            --parameters routeTableName=$routeTableName `
                            --parameters firewallPrivateIpAddress=$firewallPrivateIPAddress
    Write-Host 'Deployed Routes'
}

Function DeployAll($firewallPublicIpAddress, $vnetName, $aksSubnetName, $azFirewallName){
    Write-Host 'Deploying All'
    $outputs = az deployment group create --resource-group $resourceGroupName --template-file ./templates/azuredeploy.json `
        --parameters aksSpnClientId=$spnClientId `
        --parameters aksSpnClientSecret=$spnClientSecret `
        --parameters firewallPublicIpAddress=$firewallPublicIpAddress `
        --parameters firewallName=$azFirewallName `
        --parameters virtualNetworkName=$vnetName `
        --parameters aksSubnetName=$aksSubnetName `
        --parameters aksClusterName=$aksClusterName `
        --parameters adminWorkStationPassword=$adminWorkStationAdminPassword `
        --parameters sqlAdminPassword=$sqlServerAdminPassword
    Write-Host 'Deployed All'
}

Function DeployK8sResources() {
    [string]$azureConfigJson = @{tenantId=$tenantID;subscriptionId=$subscriptionID;resourceGroup=$resourceGroupName;aadClientId=$spnClientId;aadClientSecret=$spnClientSecret} | ConvertTo-Json -Compress | Out-String
   $azureConfigJsonBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($azureConfigJson))
   $subscriptionIDBase64 = ToBase64 -value $subscriptionID
   $clientIDBase64 = ToBase64 -value $spnClientId
   $clientSecretBase64 = ToBase64 -value $spnClientSecret
   $tenantIDBase64 = ToBase64 -value $tenantID

   Get-Content -Path "./k8s/manifests/ingressvalues-template.yaml" | ForEach-Object {
       $_ -replace '#{LOADBALANCER-IP}#', $ingressLoadBalancerIpAddress
   } | Set-Content "./k8s/manifests/ingressvalues.yaml"

   Get-Content -Path "./k8s/manifests/externaldns/deploy-template.yaml" | ForEach-Object {
       $_ -replace '#{AZURE-CONFIG-JSON}#', $azureConfigJsonBase64 `
          -replace '#{AZURE-DNSZONE-RESOURCEGROUP}#', $resourceGroupName `
          -replace '#{AZURE-DNSZONE-SUBSCRIPTIONID}#', $subscriptionID `
          -replace '#{AZURE-DNSZONE-DOMAINFILTER}#', $dnsZoneName `
          -replace '#{NAMESPACE}#', 'azsecurity' `
          -replace '#{AZURE-SUBSCRIPTION-ID}#', $subscriptionIDBase64 `
          -replace '#{AZURE-CLIENT-ID}#', $clientIDBase64 `
          -replace '#{AZURE-CLIENT-SECRET}#', $clientSecretBase64 `
          -replace '#{AZURE-TENANT-ID}#', $tenantIDBase64
   } | Set-Content "./k8s/manifests/externaldns/deploy.yaml"

   az aks get-credentials -n $aksClusterName -g $resourceGroupName --subscription $subscriptionID --file config --overwrite-existing
   Invoke-Expression -Command "kubectl apply -f './k8s/manifests/namespace.yaml' --kubeconfig=config --insecure-skip-tls-verify"
   Invoke-Expression -Command "helm upgrade --namespace=azsecurity --install --wait --values './k8s/manifests/ingressvalues.yaml' --kubeconfig=config ingress './k8s/charts/ingress-nginx-3.23.0.tgz'"
   Invoke-Expression -Command "kubectl apply -f './k8s/manifests/externaldns/deploy.yaml' -n=azsecurity --kubeconfig=config"
   Invoke-Expression -Command "kubectl apply -f './k8s/manifests/juiceshop/deploy.yaml' -n=azsecurity --kubeconfig=config"

   #Remove-Item -Path "./config"
   Remove-Item -Path "./k8s/manifests/externaldns/deploy.yaml"
}


CreateUsersAndGroups
$firewallPublicIPAddressDetail = DeployPublicIpAddress -azFirewallName $azFirewallName
$firewallPublicIPAddress = $firewallPublicIPAddressDetail.firewallIpAddress
$firewallPublicIPAddressName = $firewallPublicIPAddressDetail.name
$networkDetail = DeployNetwork
$vnetName = $networkDetail.vnetName
$routeTableName = $networkDetail.routeTableName
$aksSubnetName = $networkDetail.aksSubnetName
$firewallPrivateIPAddress = DeployFirewall -azFirewallName $azFirewallName -vnetName $vnetName -firewallPublicIpAddressName $firewallPublicIPAddressName -firewallPublicIpAddress $firewallPublicIPAddress
DeployRoutes -routeTableName $routeTableName -firewallPrivateIPAddress $firewallPrivateIPAddress
DeployAdminWorkstation -adminWorkStationAdminPassword $adminWorkStationAdminPassword -vnetName $vnetName
DeployAll -firewallPublicIpAddress $firewallPublicIPAddress -vnetName $vnetName -aksSubnetName $aksSubnetName -azFirewallName $azFirewallName
DeployK8sResources
