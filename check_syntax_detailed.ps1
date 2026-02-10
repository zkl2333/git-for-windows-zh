# PowerShell 脚本语法检查工具
# 用于 GitHub Actions 自动化测试

$ErrorActionPreference = 'Stop'

try {
    # 设置编码（PowerShell 5.1 需要）
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    }

    # 要检查的脚本列表
    $scriptsToCheck = @(
        './apply_git_language_pack.ps1',
        './install.ps1'
    )

    $allPassed = $true

    foreach ($scriptPath in $scriptsToCheck) {
        Write-Host "`n" + "=" * 60
        Write-Host "检查脚本: $scriptPath" -ForegroundColor Cyan
        Write-Host "=" * 60

        if (-not (Test-Path $scriptPath)) {
            Write-Host "⚠️  脚本文件不存在: $scriptPath" -ForegroundColor Yellow
            continue
        }

        # 读取脚本内容
        $content = Get-Content -Path $scriptPath -Raw -Encoding UTF8

        Write-Host "脚本长度: $($content.Length) 字符"

        # 使用 PSParser 检查语法错误
        $errors = $null
        [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors) | Out-Null

        if ($errors.Count -gt 0) {
            Write-Host '❌ 发现语法错误:' -ForegroundColor Red
            $errors | ForEach-Object {
                Write-Host "  第 $($_.Token.StartLine) 行: $($_.Message)" -ForegroundColor Red
            }
            $allPassed = $false
        } else {
            Write-Host '✅ 语法检查通过' -ForegroundColor Green
        }
    }

    Write-Host "`n" + "=" * 60
    if ($allPassed) {
        Write-Host "🎉 所有脚本语法检查通过！" -ForegroundColor Green
        Write-Host "=" * 60
        exit 0
    } else {
        Write-Host "❌ 部分脚本存在语法错误" -ForegroundColor Red
        Write-Host "=" * 60
        exit 1
    }
} catch {
    Write-Host "❌ 语法检查失败: $_" -ForegroundColor Red
    exit 1
}
