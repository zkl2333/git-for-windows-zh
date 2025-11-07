# apply_git_language_pack.ps1

# 兼容性检查和编码保护
try {
    # 为Windows PowerShell (5.1及以下) 设置UTF-8编码
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    }
} catch {
    Write-Warning "编码设置失败，继续执行脚本..."
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
    $gitCommand = Get-Command git -ErrorAction Stop
    $gitPath = $gitCommand.Source
} catch {
    Write-Host "错误：未找到Git，请确保已安装Git并将其添加到系统PATH环境变量中。" -ForegroundColor Red
    Write-Host "下载地址：https://git-scm.com/download/win" -ForegroundColor Yellow
    Read-Host "按任意键退出..."
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
    try {
        Remove-Item -Path $tempExtractDir -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Warning "无法删除临时目录，尝试使用其他方法..."
        $tempExtractDir = "$env:TEMP\git-lang-pack_$(Get-Random)"
    }
}

try {
    # 兼容不同版本的PowerShell
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        Expand-Archive -LiteralPath $tempZipFile -DestinationPath $tempExtractDir -Force -ErrorAction Stop
    } else {
        # 对于旧版本，使用Shell.Application对象
        $shell = New-Object -ComObject Shell.Application
        $zip = $shell.NameSpace($tempZipFile)
        foreach($item in $zip.items()) {
            $shell.Namespace($tempExtractDir).CopyHere($item, 0x14)
        }
    }
} catch {
    Write-Host "错误：解压失败。$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

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

Write-Host "正在设置用户环境变量：$envName=$envValue"
try {
    [Environment]::SetEnvironmentVariable($envName, $envValue, [EnvironmentVariableTarget]::User)
    Write-Host "✓ 环境变量设置成功"
    Write-Host "⚠ 请重启 Git Bash 使环境变量生效"
} catch {
    Write-Host "⚠ 环境变量设置失败：$($_.Exception.Message)"
    Write-Host "💡 您可以手动设置环境变量或参考文档中的其他方法"
}

# 设置Git编码配置
Write-Host "正在配置Git编码设置..."
try {
    & git config --global core.quotepath false
    & git config --global gui.encoding utf-8
    & git config --global i18n.commitencoding utf-8
    & git config --global i18n.logoutputencoding utf-8
    Write-Host "✓ Git编码配置完成"
} catch {
    Write-Warning "Git编码配置失败，您可以手动执行以下命令："
    Write-Host "git config --global core.quotepath false"
    Write-Host "git config --global gui.encoding utf-8"
    Write-Host "git config --global i18n.commitencoding utf-8"
    Write-Host "git config --global i18n.logoutputencoding utf-8"
}

Write-Host ""
Write-Host "🎉 语言包安装完成！"
Write-Host ""
Write-Host "📋 下一步操作："
Write-Host "1. 重启 Git Bash"
Write-Host "2. 运行 'git status' 验证中文显示"
Write-Host ""
Write-Host "📖 如果仍显示英文，请参考文档中的手动设置方法："
Write-Host "   - bash profile 配置"
Write-Host "   - 系统环境变量设置"

# 清理临时文件
Write-Host "正在清理临时文件..."
Remove-Item -Path $tempZipFile -Force
Remove-Item -Path $tempExtractDir -Recurse -Force
