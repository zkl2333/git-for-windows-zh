# Git for Windows 中文语言包一键安装脚本
# 使用方法：iwr -useb https://cdn.jsdelivr.net/gh/zkl2333/git-for-windows-zh@main/install.ps1 | iex

# 使用 & { } 包裹脚本，确保通过 iwr | iex 运行时 return 不会关闭 PowerShell 窗口
& {
    # 兼容性检查和编码保护
    try {
        # 为Windows PowerShell (5.1及以下) 设置UTF-8编码
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        }
    } catch {
        Write-Warning "编码设置失败，继续执行脚本..."
    }

    # 确保可以连接到 GitHub（设置 TLS 1.2）
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        Write-Warning "TLS 设置失败，继续执行脚本..."
    }

    # 设置GitHub仓库信息
    $GitHubUser = "zkl2333"
    $GitHubRepo = "git-for-windows-zh"
    $InstallUrl = "https://cdn.jsdelivr.net/gh/$GitHubUser/$GitHubRepo@main/install.ps1"

    Write-Host "🚀 Git for Windows 中文语言包安装程序" -ForegroundColor Cyan
    Write-Host ("=" * 50)

    # 检查PowerShell版本
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host "❌ 需要 PowerShell 版本 5.0 或更高版本" -ForegroundColor Red
        Write-Host "   当前版本：$($PSVersionTable.PSVersion)" -ForegroundColor Yellow
        return
    }

    # 检查管理员权限
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "⚠️  检测到未以管理员身份运行" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "请以管理员身份运行 PowerShell，然后执行：" -ForegroundColor Cyan
        Write-Host "iwr -useb $InstallUrl | iex" -ForegroundColor Green
        Write-Host ""
        $response = Read-Host "是否尝试以管理员身份重新启动？(Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            try {
                Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"iwr -useb $InstallUrl | iex; Read-Host '按 Enter 键关闭窗口'`""
                Write-Host "✅ 已启动管理员 PowerShell 窗口，请在新窗口中继续操作" -ForegroundColor Green
                return
            } catch {
                Write-Host "❌ 无法启动管理员 PowerShell：$($_.Exception.Message)" -ForegroundColor Red
                return
            }
        } else {
            return
        }
    }

    Write-Host "✅ 已确认管理员权限" -ForegroundColor Green

    # 获取git.exe的路径
    try {
        $gitCommand = Get-Command git -ErrorAction Stop
        $gitPath = $gitCommand.Source
        Write-Host "✅ 已找到 Git：$gitPath" -ForegroundColor Green
    } catch {
        Write-Host "❌ 未找到 Git，请先安装 Git for Windows" -ForegroundColor Red
        Write-Host "   下载地址：https://git-scm.com/download/win" -ForegroundColor Yellow
        return
    }

    # 获取Git安装目录
    $gitDir = Split-Path $gitPath -Parent
    $gitInstallDir = Split-Path $gitDir -Parent

    Write-Host "📁 Git 安装目录：$gitInstallDir" -ForegroundColor Cyan

    # 获取已安装的Git版本
    $gitVersionOutput = & git --version
    if ($gitVersionOutput -match "git version (\d+\.\d+\.\d+(?:\.\w+)?(?:\.\d+)?)") {
        $gitVersion = $Matches[1]
        Write-Host "📦 已安装的 Git 版本：$gitVersion" -ForegroundColor Cyan
    } else {
        Write-Host "❌ 无法获取 Git 版本号" -ForegroundColor Red
        return
    }

    # 构建语言包下载URL
    $downloadUrl = "https://github.com/$GitHubUser/$GitHubRepo/releases/download/v$gitVersion/build-$gitVersion.zip"

    Write-Host "🔗 语言包下载地址：$downloadUrl" -ForegroundColor Cyan

    # 设置临时文件和目录
    $tempZipFile = Join-Path $env:TEMP "build-$gitVersion.zip"
    $tempExtractDir = Join-Path $env:TEMP "git-lang-pack"

    # 下载语言包
    Write-Host ""
    Write-Host "⬇️  正在下载语言包..." -ForegroundColor Yellow
    try {
        # 禁用进度条以加快下载速度（PowerShell 5.1 的进度条会严重拖慢下载）
        $oldProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZipFile -UseBasicParsing -ErrorAction Stop
        Write-Host "✅ 语言包下载成功" -ForegroundColor Green
    } catch {
        Write-Host "❌ 下载语言包失败" -ForegroundColor Red
        Write-Host "   请检查该版本的语言包是否存在：v$gitVersion" -ForegroundColor Yellow
        Write-Host "   所有可用版本：https://github.com/$GitHubUser/$GitHubRepo/releases" -ForegroundColor Yellow
        Write-Host "   错误信息：$($_.Exception.Message)" -ForegroundColor Red
        return
    } finally {
        $ProgressPreference = $oldProgressPreference
    }

    # 解压语言包
    Write-Host "📦 正在解压语言包..." -ForegroundColor Yellow
    if (Test-Path $tempExtractDir) {
        try {
            Remove-Item -Path $tempExtractDir -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Warning "无法删除临时目录，尝试使用其他方法..."
            $tempExtractDir = Join-Path $env:TEMP "git-lang-pack_$(Get-Random)"
        }
    }

    try {
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            Expand-Archive -LiteralPath $tempZipFile -DestinationPath $tempExtractDir -Force -ErrorAction Stop
        } else {
            $shell = New-Object -ComObject Shell.Application
            $zip = $shell.NameSpace($tempZipFile)
            foreach($item in $zip.items()) {
                $shell.Namespace($tempExtractDir).CopyHere($item, 0x14)
            }
        }
        Write-Host "✅ 语言包解压成功" -ForegroundColor Green
    } catch {
        Write-Host "❌ 解压失败：$($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # 备份原始文件（可选）
    $backupDir = Join-Path $gitInstallDir "backup_lang_$(Get-Date -Format 'yyyyMMddHHmmss')"
    Write-Host "💾 正在备份原始语言文件到：$backupDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    $filesToBackup = @(
        (Join-Path $gitInstallDir "mingw64\share\locale\zh_CN\LC_MESSAGES\git.mo"),
        (Join-Path $gitInstallDir "mingw64\share\git-gui\lib\msgs\zh_cn.msg"),
        (Join-Path $gitInstallDir "mingw64\share\gitk\lib\msgs\zh_cn.msg")
    )

    foreach ($file in $filesToBackup) {
        if (Test-Path $file) {
            $destination = $file.Replace($gitInstallDir, $backupDir)
            New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
            Copy-Item -Path $file -Destination $destination -Force
        }
    }

    # 复制新的语言文件到Git安装目录
    Write-Host "📋 正在复制新的语言文件..." -ForegroundColor Yellow
    try {
        Copy-Item -Path (Join-Path $tempExtractDir "*") -Destination $gitInstallDir -Recurse -Force
        Write-Host "✅ 语言文件复制成功" -ForegroundColor Green
    } catch {
        Write-Host "❌ 复制文件失败：$($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # 设置LANG环境变量
    $envName = "LANG"
    $envValue = "zh_CN.UTF-8"

    Write-Host "🔧 正在设置用户环境变量：$envName=$envValue" -ForegroundColor Yellow
    try {
        [Environment]::SetEnvironmentVariable($envName, $envValue, [EnvironmentVariableTarget]::User)
        Write-Host "✅ 环境变量设置成功" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  环境变量设置失败：$($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "💡 您可以手动设置环境变量或参考文档中的其他方法" -ForegroundColor Cyan
    }

    # 设置Git编码配置
    Write-Host "🔧 正在配置 Git 编码设置..." -ForegroundColor Yellow
    try {
        & git config --global core.quotepath false
        & git config --global gui.encoding utf-8
        & git config --global i18n.commitencoding utf-8
        & git config --global i18n.logoutputencoding utf-8
        Write-Host "✅ Git 编码配置完成" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Git 编码配置失败" -ForegroundColor Yellow
        Write-Host "💡 您可以手动执行以下命令：" -ForegroundColor Cyan
        Write-Host "   git config --global core.quotepath false"
        Write-Host "   git config --global gui.encoding utf-8"
        Write-Host "   git config --global i18n.commitencoding utf-8"
        Write-Host "   git config --global i18n.logoutputencoding utf-8"
    }

    # 清理临时文件
    Write-Host "🧹 正在清理临时文件..." -ForegroundColor Yellow
    try {
        Remove-Item -Path $tempZipFile -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ 临时文件清理完成" -ForegroundColor Green
    } catch {
        Write-Warning "清理临时文件时出现错误，可以手动删除：$tempZipFile 和 $tempExtractDir"
    }

    # 显示完成信息
    Write-Host ""
    Write-Host ("=" * 50)
    Write-Host "🎉 语言包安装完成！" -ForegroundColor Green
    Write-Host ("=" * 50)
    Write-Host ""
    Write-Host "📋 下一步操作：" -ForegroundColor Cyan
    Write-Host "  1. 重启 Git Bash" -ForegroundColor White
    Write-Host "  2. 运行 'git status' 验证中文显示" -ForegroundColor White
    Write-Host ""
    Write-Host "📖 如果仍显示英文，请参考文档中的手动设置方法：" -ForegroundColor Cyan
    Write-Host "   https://github.com/$GitHubUser/$GitHubRepo" -ForegroundColor Blue
    Write-Host ""
}
