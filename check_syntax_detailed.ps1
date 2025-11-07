# PowerShell 脚本语法检查工具
# 用于 GitHub Actions 自动化测试

$ErrorActionPreference = 'Stop'

try {
    # 设置编码（PowerShell 5.1 需要）
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    }

    $scriptPath = './apply_git_language_pack.ps1'

    # 读取脚本内容
    $content = Get-Content -Path $scriptPath -Raw -Encoding UTF8

    Write-Host "Script length: $($content.Length) characters"

    # 使用 PSParser 检查语法错误
    $errors = $null
    [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors) | Out-Null

    if ($errors.Count -gt 0) {
        Write-Host '❌ Syntax errors found:'
        $errors | ForEach-Object {
            Write-Host "  Line $($_.Token.StartLine): $($_.Message)"
        }
        exit 1
    }

    Write-Host '✅ Syntax check passed'
} catch {
    Write-Host "❌ Syntax check failed: $_"
    exit 1
}
