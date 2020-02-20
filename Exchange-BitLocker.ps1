# This will encrypt all remaining drives on the Exchange server after you have encrypted the boot volume
# This script assumes you have applied group policy that will enforce the various BitLocker options you
# want enabled on each drive.

function EncryptDrive($MountPoint) {
    if ( $(Get-BitLockerVolume -MountPoint $MountPoint).VolumeStatus -like "FullyDecrypted"){
        $BLPassword = ConvertTo-SecureString "( -join ((48..57) + (97..122) | Get-Random -Count 64 | ForEach-Object {[char]$_}) )" -AsPlainText -Force
        Enable-BitLocker -MountPoint $MountPoint -PasswordProtector -Password $BLPassword
        Start-Sleep -Seconds 5
        Enable-BitLockerAutoUnlock -MountPoint $MountPoint
        Add-BitLockerKeyProtector -MountPoint $MountPoint -RecoveryPasswordProtector
    }

}

# Path to Exchange Volume Mounts ** Don't forget the trailing backslash!!!
$ExchangeVols="C:\ExchangeVolumes\"

$WorkingVols = Get-ChildItem -Path $ExchangeVols

foreach ($WorkingVol in $WorkingVols) {
    EncryptDrive $("{0}{1}" -f $ExchangeVols,$WorkingVol.name)
}
