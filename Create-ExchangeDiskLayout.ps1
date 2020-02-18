# Number of physical disks
$DBDrives = $null  # Number not in quotes
# Physical disk size to target (Get by using Get-Disk and looking for the size property)
$DiskSize = $null  # Number not in quotes - e.g. Get-Disk -Number 4 | ft AllocatedSize
# Mount point directories used by the DAG - Make sure to add the trailing backslash \
$ExDB = $null  # String in quotes
$ExVol = $null  # String in quotes
# Regional Database Prefix
$DBPrefix = $null  # String in quotes
# Number of Databases
$NumDBs = $null  # Number not in quotes
# DBs per Volume
$DBsPerVol = $null  # Number not in quotes

# Functions
function SanityCheck() {
    if ( $null -eq $DBDrives) {
        Write-Host "Variable DBDrives is empty.  Please edit the variables at the top of the script."
        return $false
    }
    
    if ( $null -eq $DiskSize) {
        Write-Host "Variable DiskSize is empty.  Please edit the variables at the top of the script."
        return $false
    }

    if ( $null -eq $ExDB) {
        Write-Host "Variable ExDB is empty.  Please edit the variables at the top of the script."
        return $false
    }

    if ( $null -eq $ExVol){
        Write-Host "Variable ExVol is empty.  Please edit the variables at the top of the script."
        return $false
    }

    if ( $null -eq $DBPrefix) {
        Write-Host "Variable DBPrefix is empty.  Please edit the variables at the top of the script."
        return $false
    }

    if ( $null -eq $NumDBs) {
        Write-Host "Variable NumDBs is empty.  Please edit the variables at the top of the script."
        return $false
    }

    if ( $null -eq $DBsPerVol) {
        Write-Host "Variable DBsPerVol is empty.  Please edit the variables at the top of the script."
        return $false
    }
    
}

function CreateRoots() {
    try {
        if (-not (Test-Path -Path $ExDB)) {
            Write-Host "Creating $ExDB"
            mkdir $ExDB
        }
        if (-not (Test-Path -Path $ExVol)) {
            Write-Host "Creating $ExVol"
            mkdir $ExVol
        }
    } catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host $ErrorMessage $FailedItem
        return $false
    }
}

function CreateVolMP() {
    try {
        for ($x = 0; $x -le $DBDrives; $x++) {
            if ($x -eq 13) {
                # Skip 13  :p  https://en.wikipedia.org/wiki/Triskaidekaphobia
            } else {
                Write-Host "Creating $("{0}{1}{2}" -f $ExVol,"\Volume",$("{0:d2}" -f $x))"
                mkdir ("{0}{1}{2}" -f $ExVol,"\Volume",$("{0:d2}" -f $x))
            }
        }
    } catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host $ErrorMessage $FailedItem
        return $false
    }
}

function PrepareDrive($DiskNumber,$VolMountNumber) {
    Write-Host "Preparing Drives..."
    try {
        if ( $(Get-Disk -Number $DiskNumber).PartitionStyle -notlike "GPT") {
            Write-Host "Initializing Disk $DiskNumber"
            Initialize-Disk -Number $DiskNumber -PartitionStyle GPT
            Start-Sleep -Seconds 3
        }
        if ( $(Get-Partition -DiskNumber $DiskNumber | Measure-Object).count -le 1) {
            Write-Host "Creating Primary Partition on Disk $DiskNumber"
            New-Partition -DiskNumber $DiskNumber -UseMaximumSize
        }

        $WorkingPartition = Get-Partition -DiskNumber $DiskNumber -PartitionNumber 2
        Write-Host "Formatting new volume as ReFS"
        $WorkingPartition | Format-Volume -FileSystem ReFS -AllocationUnitSize 65536 -SetIntegrityStreams $false

        Write-Host "Mounting new volume to $("{0}{1}{2}" -f $ExVol,"Volume",$("{0:d2}" -f $VolMountNumber))"
        $WorkingPartition | Add-PartitionAccessPath -AccessPath ("{0}{1}{2}" -f $ExVol,"Volume",$("{0:d2}" -f $VolMountNumber))
    } catch {
        Write-Host "Disk prep error."
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host $ErrorMessage $FailedItem
        return $false
    }
    

}

function DBSetup($NumDBs,$DBPrefix,$WorkingDisks,$DBsPerVol) {
    $DiskNum = 0
    $DBPVNum = 0
    for ($x = 0; $x -lt $NumDBs; $x++ ) {
        if (-not (Test-Path -Path $("{0}{1}{2}{3}" -f $ExDB,$DBPrefix,"DB19",$("{0:d2}" -f $x)))) {
            mkdir ("{0}{1}{2}{3}" -f $ExDB,$DBPrefix,"DB19",$("{0:d2}" -f $x))
        }

        $WorkingPartition = Get-Partition -DiskNumber $WorkingDisks[$DiskNum] -PartitionNumber 2
        $WorkingPartition | Add-PartitionAccessPath -AccessPath ("{0}{1}{2}{3}" -f $ExDB,$DBPrefix,"DB19",$("{0:d2}" -f $x))
        if (-not (Test-Path -Path $("{0}{1}{2}{3}{4}{5}{6}{7}{8}" -f $ExDB,$DBPrefix,"DB19",$("{0:d2}" -f $x),"\",$DBPrefix,"DB19",$("{0:d2}" -f $x),".db"))) {
            Write-Host "Creating directory $("{0}{1}{2}{3}{4}{5}{6}{7}{8}" -f $ExDB,$DBPrefix,"DB19",$("{0:d2}" -f $x),"\",$DBPrefix,"DB19",$("{0:d2}" -f $x),".db")"
            mkdir ("{0}{1}{2}{3}{4}{5}{6}{7}{8}" -f $ExDB,$DBPrefix,"DB19",$("{0:d2}" -f $x),"\",$DBPrefix,"DB19",$("{0:d2}" -f $x),".db")
        }
        if (-not (Test-Path -Path $("{0}{1}{2}{3}{4}{5}{6}{7}{8}" -f $ExDB,$DBPrefix,"DB19",$("{0:d2}" -f $x),"\",$DBPrefix,"DB19",$("{0:d2}" -f $x),".log"))){
            Write-Host "Creating directory $("{0}{1}{2}{3}{4}{5}{6}{7}{8}" -f $ExDB,$DBPrefix,"DB19",$("{0:d2}" -f $x),"\",$DBPrefix,"DB19",$("{0:d2}" -f $x),".log")"
            mkdir ("{0}{1}{2}{3}{4}{5}{6}{7}{8}" -f $ExDB,$DBPrefix,"DB19",$("{0:d2}" -f $x),"\",$DBPrefix,"DB19",$("{0:d2}" -f $x),".log")
        }

        $DBPVNum++
        if ($DBPVNum -eq $DBsPerVol) {
            $DiskNum++
            $DBPVNum = 0
        }
    }
}

# Sanity Check - make sure all the variables are populated
SanityCheck

# Create the root mount point directories according to the DAG settings
CreateRoots

# Create the mount points for the physical disks
CreateVolMP

# Identitfy the physical disks, create GPT primary partition, format ReFS 64k file allocation unit
# size, and mount the disks under their volume folders created in the last step

try {
    $WorkingDisks = $(Get-Disk | Where-Object {$_.Size -eq $DiskSize}).Number
    if ( $WorkingDisks.count -ne $DBDrives) {
        Write-Host "Drives discovered does not match the number of DB drives you specified"
        exit 1
    }
} catch {
    Write-Host "Disk get error"
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Write-Host $ErrorMessage $FailedItem
    return $false
}

$z = 0
foreach ($WorkingDisk in $WorkingDisks) {
    if ($z -eq 13) {
        # Skip 13  :p  https://en.wikipedia.org/wiki/Triskaidekaphobia
        $z++
        Write-Host "Calling PrepareDrive Function with $WorkingDisk and $z"
        PrepareDrive $WorkingDisk $z
    } else {
        Write-Host "Calling PrepareDrive Function with $WorkingDisk and $z"
        PrepareDrive $WorkingDisk $z
        $z++
    }
}

try {
    DBSetup $NumDBs $DBPrefix $WorkingDisks $DBsPerVol
    #return $true
} catch {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Write-Host $ErrorMessage $FailedItem
    return $false
}


