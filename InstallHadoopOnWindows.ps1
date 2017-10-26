<# This script installs Hadoop and sets it up for Windows #>
# Where to install Hadoop, version, filename.
$INSTALL_DIR = $HOME
$VERSION = "2.8.1"
$HADOOP = "hadoop-$VERSION"
$MIRROR = "http://apache.mirrors.hoobly.com/hadoop/common/$HADOOP/$HADOOP.tar.gz"
$SIGURL = "https://dist.apache.org/repos/dist/release/hadoop/common/$HADOOP/$HADOOP-src.tar.gz.asc"

# Move to the install directory
cd "$INSTALL_DIR"

# Download the compressed Hadoop binary
Invoke-WebRequest -Uri $MIRROR -OutFile "$INSTALL_DIR\$HADOOP.tar.gz"

# Verify download files weren't corrupted
#Invoke-WebRequest -Uri $SIGURL

# Uncompress files (must be admin for this step; must have 7-zip)
7z x "$HADOOP.tar.gz"
7z x "$HADOOP.tar"
rm "$HADOOP.tar.gz"
rm "$HADOOP.tar"

# Set HADOOP_HOME for your user
[Environment]::SetEnvironmentVariable("HADOOP_HOME", "$INSTALL_DIR\$HADOOP", "User")

# Add HADOOP_HOME to path
# Manual step, so that PATH doesn't get accidentally clobbered.

# Set JAVA_HOME in Hadoop's hadoop-env.cmd file. Use the "ShortPath" equivalent,
# because any spaces/quotes in the path causes problems.
$fso = New-Object -com Scripting.FileSystemObject
$javaHome = Split-Path -Parent $(Get-Command java).Source
$javaShort = $fso.GetFolder($javaHome).ShortPath

$envFile = "$INSTALL_DIR\$HADOOP\etc\hadoop\hadoop-env.cmd"
(Get-Content $envFile).replace("%JAVA_HOME%", $javaShort) | Set-Content "$envFile.tmp"

# Copy winutils over from git repo
$repoDir = (Split-Path -Parent $MyInvocation.MyCommand.Definition)
cp "$repoDir\winutils\$HADOOP\*" "$INSTALL_DIR\$HADOOP\bin"

# Copy Hadoop config files for pseudo-distributed mode
cp "$repoDir\config\*" "$INSTALL_DIR\$HADOOP\etc\hadoop"

# Create hadoop data folders
$nameDir = "C:\opt\hadoop\dfs\name"
$dataDir = "C:\opt\hadoop\dfs\data"
if (-Not $(Test-Path $nameDir)) mkdir $nameDir
if (-Not $(Test-Path $dataDir)) mkdir $dataDir

# Format namenode
& "$INSTALL_DIR\$HADOOP\bin\hadoop" namenode -format
