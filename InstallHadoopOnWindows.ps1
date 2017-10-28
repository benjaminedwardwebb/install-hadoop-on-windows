<# 
	.SYNOPSIS 
	This script installs Hadoop and sets it up for Windows.
#>
# Static vars, like where to install & version number.
$INSTALL_DIR = "$HOME"
$VERSION = "2.8.1"
$HADOOP = "hadoop-$VERSION"
$URL = "http://apache.mirrors.hoobly.com/hadoop/common/$HADOOP/$HADOOP.tar.gz"

# Download
cd "$INSTALL_DIR"
Invoke-WebRequest -Uri $URL -OutFile "$INSTALL_DIR\$HADOOP.tar.gz"

# Uncompress (must be admin for this step; must have 7-zip)
$codeBlock = 
	"cd `"$INSTALL_DIR`"; 
	7z x `"$HADOOP.tar.gz`"; 
	7z x `"$HADOOP.tar`"; 
	rm `"$HADOOP.tar.gz`"; 
	rm `"$HADOOP.tar`""
$process = Start-Process -FilePath powershell.exe `
	-verb RunAs -WorkingDirectory "$INSTALL_DIR" `
	-ArgumentList "-Command & { $codeBlock }" -PassThru
$process.WaitForExit()

# Set HADOOP_HOME for user
[Environment]::SetEnvironmentVariable(
	"HADOOP_HOME", 
	"$INSTALL_DIR\$HADOOP", 
	"User"
)

# Set JAVA_HOME for Hadoop
# This step tries a few different ways of getting a workable 
# path to java. First it tries your JAVA_HOME, then the 
# location of java on your path, and finally it looks in 
# C:\Program Files\Java for jdk/jre folders of version 6, 7, 
# or 8.
$javaHome = ""

$javas = @(
	$env:JAVA_HOME, 
	$(Split-Path -Parent $(Get-Command java).Source)
)
$jres = $(gci "C:\Program Files\Java").FullName -match "6|7|8"
$javas = $javas + $jres

for ($i = 0; $i -lt $javas.Length; $i++) {
	$java = $javas[$i]
	if (Test-Path "$java\bin\java.exe") {
		$javaHome = $java
		break;
	}
}

if ($javaHome -ne "") {
	$fso = New-Object -com Scripting.FileSystemObject
	$javaShort = $fso.GetFolder($javaHome).ShortPath
	$envFile = "$INSTALL_DIR\$HADOOP\etc\hadoop\hadoop-env.cmd"
	(Get-Content $envFile).replace("%JAVA_HOME%", $javaShort) | 
		Set-Content "$envFile"
}

# Copy winutils from git repo
$repoDir = $(Split-Path -Parent $MyInvocation.MyCommand.Definition)
cp "$repoDir\winutils\$HADOOP\*" "$INSTALL_DIR\$HADOOP\bin"

# Copy config files for pseudo-distributed mode
cp "$repoDir\config\*" "$INSTALL_DIR\$HADOOP\etc\hadoop"

# Create data folders (these should match hdfs-site.xml)
$nameDir = "C:\opt\hadoop\dfs\name"
$dataDir = "C:\opt\hadoop\dfs\data"
if (-Not $(Test-Path $nameDir)) { mkdir $nameDir }
if (-Not $(Test-Path $dataDir)) { mkdir $dataDir }

# Format namenode
& "$INSTALL_DIR\$HADOOP\bin\hadoop" namenode -format

Write-Host "Done. Close & open new shell before starting Hadoop."
