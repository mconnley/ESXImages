$datacenterName = "HomeLab"
$clusterName = "ImageBuildOnly"
$esxiImageName = "8.0 U3c - 24414501"
$esxiComponentName = "VMware USB NIC Fling Driver"
$esxiComponentVersion = "1.14-2vmw"

$vc = $args[0]
$certUrl = "https://$($vc)/certs/download.zip"
Invoke-WebRequest $certUrl -OutFile "/tmp/download.zip" -SkipCertificateCheck
Expand-Archive -Path "/tmp/download.zip" -DestinationPath "/tmp"
Get-ChildItem -Path "/tmp/certs/lin/" -Filter "*.0" | Select-Object -First 1 | Copy-Item -Destination "/usr/local/share/ca-certificates/vc.crt"
update-ca-certificates

Connect-VIServer -Server $vc
$esxiBaseImage = Get-LcmImage -Type BaseImage -Version $esxiImageName
$esxiComponent = Get-LcmImage -Type Component | Where-Object {$_.Name -eq $esxiComponentName -and $_.Version -eq $esxiComponentVersion}

New-Cluster -Name $clusterName -BaseImage $esxiBaseImage -Location (Get-Datacenter -Name $datacenterName)
Get-Cluster -Name $clusterName | Set-Cluster -Component @($esxiComponent) -BaseImage $esxiBaseImage -Confirm:$false
Export-LcmClusterDesiredState -Cluster (Get-Cluster -Name $clusterName) -ExportIsoImage -Destination "/tmp/imagebuilds"
Get-Cluster -Name $clusterName | Remove-Cluster -Confirm:$false
