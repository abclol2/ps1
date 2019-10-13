param (
[String]$Server="",
[String]$User="sa",
[String]$PW="manager",
[String]$DB="",
[String]$Ort="\\192.168.20.239\dbtest",
[String]$NW="\\192.168.20.239\dbtest",
[String]$NW2="\\192.168.111.251\dbtest",
[String]$bakName="",
[String]$PWFile="C:\tmp\PW.txt"
)

if ($Server -eq ""){$Server = Read-Host "SQLServer Namen oder IP(\Instanz) eingeben "}
if ($Server -eq ""){exit}

if ($User -eq ""){$User = Read-Host "Bitte DB User angeben[sa]"}
if ($User -eq ""){$User = "sa"}

if ($PW -eq ""){$PW = Read-Host "Bitte DB PW angeben[sa]"}
if ($PW -eq "")
{$pass = Read-Host -assecurestring "Bitte Passwort eingeben"}
else
{$pass = $PW | ConvertTo-SecureString -AsPlainText -Force}

$login = New-Object System.Management.Automation.PsCredential ($User, $pass)

if ($DB -eq ""){$DB = Read-Host "Bitte DB eingeben"}
if ($DB -eq ""){exit}

if ($Ort -eq ""){$Ort=Read-Host "Bitte geben Sie den Speicherort der BAK Datei an."}

if ($Ort -ne "")
{
    if ( $Ort.EndsWith("\") ) {} else {$Ort = $Ort+"\"}
}

if ($bakName -eq ""){$bakName=Read-Host "Bitte Name der BAK Datei eingeben"}
if ($bakName -eq ""){echo "Fehler";exit}

$MDFName=Invoke-Sqlcmd -ServerInstance $Server -Query "select name from sys.master_files where database_id=(SELECT DB_ID(N'$DB')) and physical_name like '%.mdf'" -Username $User -Password $PW | select -expand name
$MDFDatei=Invoke-Sqlcmd -ServerInstance $Server -Query "select physical_name from sys.master_files where database_id=(SELECT DB_ID(N'$DB')) and physical_name like '%.mdf'" -Username $User -Password $PW | select -expand physical_name
$NDFName=Invoke-Sqlcmd -ServerInstance $Server -Query "select name from sys.master_files where database_id=(SELECT DB_ID(N'$DB')) and physical_name like '%.ndf'" -Username $User -Password $PW | select -expand name
$NDFDatei=Invoke-Sqlcmd -ServerInstance $Server -Query "select physical_name from sys.master_files where database_id=(SELECT DB_ID(N'$DB')) and physical_name like '%.ndf'" -Username $User -Password $PW | select -expand physical_name
$LDFName=Invoke-Sqlcmd -ServerInstance $Server -Query "select name from sys.master_files where database_id=(SELECT DB_ID(N'$DB')) and physical_name like '%.ldf'" -Username $User -Password $PW | select -expand name
$LDFDatei=Invoke-Sqlcmd -ServerInstance $Server -Query "select physical_name from sys.master_files where database_id=(SELECT DB_ID(N'$DB')) and physical_name like '%.ldf'" -Username $User -Password $PW | select -expand physical_name

$RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($MDFName, $MDFDatei)
$RelocateNDF = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($NDFName, $NDFDatei)
$RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($LDFName, $LDFDatei)

if (0 -eq (Invoke-Sqlcmd -ServerInstance $Server -Query "select value_in_use from sys.configurations where name = 'xp_cmdshell'" -Username sa -Password $PW | select -expand value_in_use)) 
{
	Invoke-Sqlcmd -ServerInstance $Server -Query "EXEC sp_configure 'show advanced options', 1" -Username sa -Password $PW
	Invoke-Sqlcmd -ServerInstance $Server -Query "RECONFIGURE" -Username sa -Password $PW
	Invoke-Sqlcmd -ServerInstance $Server -Query "EXEC sp_configure 'xp_cmdshell', 1" -Username sa -Password $PW
	Invoke-Sqlcmd -ServerInstance $Server -Query "RECONFIGURE" -Username sa -Password $PW
	echo "xp_cmdshell wurde aktiviert."
}

Invoke-Sqlcmd -ServerInstance $Server -Query "EXEC XP_CMDSHELL 'net use $NW /persistent:no /user:dbtest dbtest'" -Username sa -Password $PW
Restore-SqlDatabase -ServerInstance $Server -Database $DB -BackupFile $Ort$bakName -ReplaceDatabase -RelocateFile @($RelocateData,$RelocateNDF,$RelocateLog) -Credential $login
Invoke-Sqlcmd -ServerInstance $Server -Query "EXEC XP_CMDSHELL 'net use /d $NW'" -Username sa -Password $PW