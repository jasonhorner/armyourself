
<#
.SYNOPSIS
    Registers RPs
#>


#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************





#$VerbosePreference = "Continue"

$DebugPreference = "Continue"
$ErrorActionPreference = "Stop"


$deploymentName = "jjhtest"

$subscriptionName = "Rhapsody Staging"
$tenantId = "2acebf54-1bc8-4c4d-a034-60d2fb4b2359"

<# one time
Enable-AzContextAutosave
Connect-AzAccount -Tenant $tenantId -Subscription $subscriptionName
#>

Set-AzContext -Subscription $subscriptionName -Tenant $tenantId | Out-Null


$resourceGroupName = "StagingBI"

# The location of your local repository
$basePath = "C:\Users\BigJi\Source\Repos\BI-IaC"
Push-Location $basepath

$armTemplatePath = Join-Path $basePath "Templates\bi"

$parametersFilePath = Join-Path $armTemplatePath "parameters.json"
$templateFilePath = Join-Path $armTemplatePath  "azuredeploy.json"

$hosts = @("sta-sc-gateway", "sta-sc-pbirs", "sta-sc-ssas", "sta-sc-ssis", "sta-sc-ssrs", "sta-sc-pyraweb")


# Validate the deployment
Write-Host "Validating deployment..."
"Resource Group: {0} ( {1})" -f $resourceGroupName, $(Get-AzContext).Subscription.Name

Write-Host "Template Information:   "
"Template: {0}  Parameters: {1}" -f $templateFilepath, $parametersFilePath


if (Test-Path $parametersFilePath) {
    if (Test-Path $parametersFilePath) {
        Test-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -Verbose
    }
    else {
        Test-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -Verbose 
    }
}









function deployArmTemplate {
param (
    [string] $resourceGroupName,
    [string] $templateFilePath,
    [string] $parametersFilePath, 
    [switch] $testOnly,
    [string[]] $hosts
)

# Validate the deployment
Write-Host "Starting deployment..."
"Resource Group: {0} ( {1})" -f $resourceGroupName, (Get-AzContext).Subscription.Name
Write-Host "Template Information:   "
"Template: {0}  Parameters: {1}" -f $templateFilepath, $parametersFilePath

if (Test-Path $parametersFilePath) {
    if (Test-Path $parametersFilePath) {
        if ($testOnly) {
          Test-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -Verbose
        }
        else {
          New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -Verbose
        }
    }
    else {
        if($testOnly) {
            Test-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -Verbose 
        }
        else {
            New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -Verbose 
        }
    }
}

}

function RemoveVMExtension {
    param (
        [string] $resourceGroupName,
        [string] $extensionName = "Microsoft.Powershell.DSC",
        [string[]] $hosts
    )
    
    foreach ($item in $hosts) {
        Write-Host "Removing extension $extensionName on $item..."    
        Remove-AzVMExtension -ResourceGroupName $resourceGroupName -Name $extensionName -VMName $item -Force 
        Write-Host "done..."
    }

}

function GetVMDscExtensionStatus {
    param (
        [string] $resourceGroupName,
        [string] $extensionName = "Microsoft.Powershell.DSC",
        [string[]] $hosts
    )
    
    foreach ($item in $hosts) {
        Write-Host "Getting extension $extensionName on $item..."    
        Get-AzVMDscExtensionStatus -ResourceGroupName $resourceGroupName -Name $extensionName -VMName $item
        Write-Host "done..."
    }

}

function PublishDscExtension {
    param (
        [string] $resourceGroupName,
        [string] $storageAccountName,
        [string] $containerName = "dsc",
        [string] $dscScriptPath
    )
    
    Write-Host "Publishing Dsc Configuration to $storageAccountName..."   

    $items = Get-ChildItem -Path $dscScriptPath -Filter "*Dsc.ps1" 
    $configurationDataPath = Get-ChildItem -Path $dscScriptPath -Filter "ConfigurationData.psd1"

    foreach ($item in $items) {
        Write-Host "Publishing Dsc Configuration $item..."   
        Publish-AzVMDscConfiguration -ConfigurationPath $item.Name -ResourceGroupName $storageResourceGroup -ContainerName $containerName -StorageAccountName $storageAccountName -ConfigurationDataPath $configurationDataPath -Force
    }

    Write-Host "done..."
}

$storageResourceGroup = "StagingServices"
$storageAccountName = "stagingservices"

$dscScriptPath = Join-Path $basePath "scripts\dsc"
Push-Location $dscScriptPath

$hosts = @("sta-sc-gateway", "sta-sc-pbirs", "sta-sc-ssas", "sta-sc-ssis", "sta-sc-ssrs", "sta-sc-pyraweb")


PublishDscExtension -resourceGroupName $storageResourceGroup -storageAccountName $storageAccountName -dscScriptPath $dscScriptPath

RemoveVMExtension -resourceGroupName $resourceGroupName -hosts $hosts

GetVMDscExtensionStatus -resourceGroupName $resourceGroupName -hosts $hosts



$rdpPath = "C:\Users\BigJi\Desktop\Red Rock\Stage"

Remove-Item -path $rdpPath

foreach ($item in $hosts) {
    $LocalPath = Join-Path  $rdpPath "$item.rdp"
    Get-AzRemoteDesktopFile -ResourceGroupName $resourceGroupName -Name $item -LocalPath $LocalPath
}


Get-AzVMExtension -ResourceGroupName $resourceGroupName -Name $extensionName -VMName "sta-sc-gateway"


Get-AzVMDscExtension -ResourceGroupName $resourceGroupName -Name $extensionName -VMName "sta-sc-gateway"

$foo = Get-AzVMDscExtensionStatus -ResourceGroupName $resourceGroupName -Name $extensionName -VMName "sta-sc-gateway"



#Get-command -noun *extension*


Set-AzVMDscExtension -WmfVersion 5.1 -Version 2.77 -AutoUpdate 

-ResourceGroupName $resourceGroupName -VMName "sta-sc-gateway" -ArchiveBlobName "gateway.ps1.zip" -ArchiveStorageAccountName $storageAccountName -ConfigurationName "GatewayDsc" -ConfigurationArgument "@ { arg="val" }" -ArchiveContainerName "dsc" -ConfigurationData "SampleData.psd1" -Version "2.77" -Location "westus2" -AutoUpdat