# apply_git_language_pack.ps1

# 编码保护 - 为Windows PowerShell设置UTF-8编码
if ($PSVersionTable.PSVersion.Major -lt 6) {
    [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
}

# 设置您的GitHub用户名和仓库名
$GitHubUser = "zkl2333"      # 替换为您的GitHub用户名
$GitHubRepo = "git-for-windows-zh"    # 替换为您的GitHub仓库名

# 检查 PowerShell 版本
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "需要 PowerShell 版本 5.0 或更高版本。当前版本：$($PSVersionTable.PSVersion)"
    exit 1
}

# 获取git.exe的路径
try {
    $gitPath = (Get-Command git).Source
} catch {
    Write-Host "未找到Git，请确保已安装Git并将其添加到系统PATH环境变量中。"
    exit 1
}

# 获取Git安装目录
$gitDir = Split-Path $gitPath -Parent
$gitInstallDir = Split-Path $gitDir -Parent

Write-Host "Git安装目录：$gitInstallDir"

# 获取已安装的Git版本
$gitVersionOutput = git --version
if ($gitVersionOutput -match "git version (\d+\.\d+\.\d+(?:\.\w+)?(?:\.\d+)?)") {
    $gitVersion = $Matches[1]
    Write-Host "已安装的Git版本：$gitVersion"
} else {
    Write-Host "无法获取Git版本号。"
    exit 1
}

# 构建语言包下载URL
$downloadUrl = "https://github.com/$GitHubUser/$GitHubRepo/releases/download/v$gitVersion/build-$gitVersion.zip"

Write-Host "语言包下载URL：$downloadUrl"

# 设置临时文件和目录
$tempZipFile = "$env:TEMP\build-$gitVersion.zip"
$tempExtractDir = "$env:TEMP\git-lang-pack"

# 下载语言包
Write-Host "正在下载语言包..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZipFile -ErrorAction Stop
} catch {
    Write-Host "下载语言包失败。请检查该版本的语言包是否存在。"
    exit 1
}

Write-Host "语言包已下载到：$tempZipFile"

# 解压语言包
Write-Host "正在解压语言包..."
if (Test-Path $tempExtractDir) {
    Remove-Item -Path $tempExtractDir -Recurse -Force
}
Expand-Archive -LiteralPath $tempZipFile -DestinationPath $tempExtractDir -Force

Write-Host "语言包已解压到：$tempExtractDir"

# 备份原始文件（可选）
$backupDir = "$gitInstallDir\backup_lang_$(Get-Date -Format 'yyyyMMddHHmmss')"
Write-Host "正在备份原始语言文件到：$backupDir"
New-Item -ItemType Directory -Path $backupDir | Out-Null

$filesToBackup = @(
    "$gitInstallDir\mingw64\share\locale\zh_CN\LC_MESSAGES\git.mo",
    "$gitInstallDir\mingw64\share\git-gui\lib\msgs\zh_cn.msg",
    "$gitInstallDir\mingw64\share\gitk\lib\msgs\zh_cn.msg"
)

foreach ($file in $filesToBackup) {
    if (Test-Path $file) {
        $destination = $file.Replace($gitInstallDir, $backupDir)
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -Path $file -Destination $destination -Force
    }
}

# 复制新的语言文件到Git安装目录
Write-Host "正在复制新的语言文件..."
Copy-Item -Path "$tempExtractDir\*" -Destination $gitInstallDir -Recurse -Force

# 设置LANG环境变量
$envName = "LANG"
$envValue = "zh_CN.UTF-8"

# 设置用户环境变量
Write-Host "正在设置用户环境变量：$envName=$envValue"
[Environment]::SetEnvironmentVariable($envName, $envValue, [EnvironmentVariableTarget]::User)

# 设置Git编码配置
Write-Host "正在配置Git编码设置..."
git config --global core.quotepath false
git config --global gui.encoding utf-8
git config --global i18n.commitencoding utf-8
git config --global i18n.logoutputencoding utf-8

Write-Host "语言包安装完成。请重新启动Git Bash以使设置生效。"

# 清理临时文件
Write-Host "正在清理临时文件..."
Remove-Item -Path $tempZipFile -Force
Remove-Item -Path $tempExtractDir -Recurse -Force
