$ErrorActionPreference = 'Stop'

$t = [Reflection.Assembly]::LoadWithPartialName("System.Web")
Write-Host "Loaded $($t.FullName)."

function CheckLoggedIn()
{
    $rmContext = Get-AzureRmContext

    if($rmContext.Account -eq $null) {
        Write-Host "You are not logged into Azure. Use Login-AzureRmAccount to log in first and optionally select a subscription" -ForegroundColor Red
        exit
    }

    Write-Host "You are running as '$($rmContext.Account.Id)' in subscription '$($rmContext.Subscription.Name)'"
}

function EnsureResourceGroup([string]$Name, [string]$Location)
{
    # Prepare resource group
    Write-Host "Checking if resource group '$Name' exists..."
    $resourceGroup = Get-AzureRmResourceGroup -Name $Name -Location $Location -ErrorAction Ignore
    if($resourceGroup -eq $null)
    {
        Write-Host "  resource group doesn't exist, creating a new one..."
        $resourceGroup = New-AzureRmResourceGroup -Name $Name -Location $Location
        Write-Host "  resource group created."
    }
    else
    {
        Write-Host "  resource group already exists."
    }
}

function EnsureKeyVault([string]$Name, [string]$ResourceGroupName, [string]$Location)
{
    # properly create a new Key Vault
    # KV must be enabled for deployment (last parameter)
    Write-Host "Checking if Key Vault '$Name' exists..."
    $keyVault = Get-AzureRmKeyVault -VaultName $Name -ErrorAction Ignore
    if($keyVault -eq $null)
    {
        Write-Host "  key vault doesn't exist, creating a new one..."
        $keyVault = New-AzureRmKeyVault -VaultName $Name -ResourceGroupName $ResourceGroupName -Location $Location -EnabledForDeployment
        Write-Host "  Key Vault Created and enabled for deployment."
    }
    else
    {
        Write-Host "  key vault already exists."
    }

    $keyVault
}

function CreateSelfSignedCertificate($DnsName)
{
    Write-Host "Creating self-signed certificate with dns name $DnsName"

    Write-Host "  generating password... " -NoNewline
    $certPassword = [System.Web.Security.Membership]::GeneratePassword(15,2)
    Write-Host "$certPassword"

    Write-Host "  generating certificate... " -NoNewline
    $securePassword = ConvertTo-SecureString $certPassword -AsPlainText -Force
    $thumbprint = (New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation Cert:\CurrentUser\My -KeySpec KeyExchange).Thumbprint
    Write-Host "$thumbprint."

    $filePath = "$PSScriptRoot\$DnsName.pfx"
    Write-Host "  exporting to $filePath..."
    $certContent = (Get-ChildItem -Path cert:\CurrentUser\My\$thumbprint)
    $t = Export-PfxCertificate -Cert $certContent -FilePath $filePath -Password $securePassword
    Write-Host "  exported."

    $thumbprint
    $certPassword
    $filePath
}

function ImportCertificateIntoKeyVault([string]$KeyVaultName, [string]$CertName, [string]$CertFilePath, [string]$CertPassword)
{
    Write-Host "Importing certificate..."
    Write-Host "  generating secure password..."
    $securePassword = ConvertTo-SecureString $CertPassword -AsPlainText -Force
    Write-Host "  uploading to KeyVault..."
    Import-AzureKeyVaultCertificate -VaultName $KeyVaultName -Name $CertName -FilePath $CertFilePath -Password $securePassword
    Write-Host "  imported."
}

function GeneratePassword()
{
    [System.Web.Security.Membership]::GeneratePassword(15,2)
}