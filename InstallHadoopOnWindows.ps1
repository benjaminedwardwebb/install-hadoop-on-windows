<# 
	.SYNOPSIS 
	This script installs Hadoop and sets it up for Windows.
#>

# Static vars, like where to install Hadoop & version number.
$INSTALL_DIR = "$HOME"
$VERSION = "2.8.1"
$HADOOP = "hadoop-$VERSION"
$MIRROR = "http://apache.mirrors.hoobly.com/hadoop/common/$HADOOP/$HADOOP.tar.gz"

# Move to the install directory
cd "$INSTALL_DIR"

# Download the compressed Hadoop binary
Invoke-WebRequest -Uri $MIRROR -OutFile "$INSTALL_DIR\$HADOOP.tar.gz"

# Uncompress files (must be admin for this step; must have 7-zip)
$codeBlock = 
	"cd `"$INSTALL_DIR`"; 
	7z x `"$HADOOP.tar.gz`"; 
	7z x `"$HADOOP.tar`"; 
	rm `"$HADOOP.tar.gz`"; 
	rm `"$HADOOP.tar`""
$process = Start-Process -FilePath powershell.exe -verb RunAs -WorkingDirectory "$INSTALL_DIR" -ArgumentList "-Command & { $codeBlock }" -PassThru
$process.WaitForExit()

# Set HADOOP_HOME for your user
[Environment]::SetEnvironmentVariable("HADOOP_HOME", "$INSTALL_DIR\$HADOOP", "User")

# Set JAVA_HOME in Hadoop's hadoop-env.cmd file. 
# This step tries a couple of times to get a "ShortPath" JAVA_HOME that works.
# First it tries your %JAVA_HOME%, then the location of java on your path, and
# then finally it tries to find it somewhere in C:\Program Files\Java. 
$javaHome = ""
$java1 = $env:JAVA_HOME
$java2 = Split-Path -Parent $(Get-Command java).Source 
if (Test-Path "$java1\bin\java.exe") {
	$javaHome = $java1
} elseif (Test-Path "$java2\bin\java.exe") {
	$javaHome = $java2
} else {
	$jres = Get-ChildItem "C:\Program Files\Java"
	for ($i = 0; $i -lt $jres.Length; $i++) {
		$java3 = $jres[$i].FullName
		if ($(Test-Path "$java3\bin\java.exe") -and $($java3 -match "6|7|8")) {
			$javaHome = $java3
			break;
		}
	}
}

if ($javaHome -ne "") {
	$fso = New-Object -com Scripting.FileSystemObject
	$javaShort = $fso.GetFolder($javaHome).ShortPath
	$envFile = "$INSTALL_DIR\$HADOOP\etc\hadoop\hadoop-env.cmd"
	(Get-Content $envFile).replace("%JAVA_HOME%", $javaShort) | 
		Set-Content "$envFile"
}

# Copy winutils over from git repo
$repoDir = (Split-Path -Parent $MyInvocation.MyCommand.Definition) # script path
cp "$repoDir\winutils\$HADOOP\*" "$INSTALL_DIR\$HADOOP\bin"

# Copy Hadoop config files for pseudo-distributed mode
cp "$repoDir\config\*" "$INSTALL_DIR\$HADOOP\etc\hadoop"

# Create hadoop data folders. These should match what's in hdfs-site.xml.
$nameDir = "C:\opt\hadoop\dfs\name"
$dataDir = "C:\opt\hadoop\dfs\data"
if (-Not $(Test-Path $nameDir)) { mkdir $nameDir }
if (-Not $(Test-Path $dataDir)) { mkdir $dataDir }

# Format namenode
& "$INSTALL_DIR\$HADOOP\bin\hadoop" namenode -format

Write-Host "Done. Close & re-open before starting Hadoop daemons."
