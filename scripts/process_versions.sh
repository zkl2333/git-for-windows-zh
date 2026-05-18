#!/bin/bash

# 启用错误追踪和管道错误检测
set -e
set -o pipefail

# 添加日志函数
log_info() {
  echo "[信息] $1"
}

log_error() {
  echo "[错误] $1" >&2
}

log_success() {
  echo "[成功] $1"
}

# 删除指定 Release（失败回滚用，避免残留草稿 Release）
delete_release() {
  local release_id="$1"
  if [ -z "$release_id" ] || [ "$release_id" = "null" ]; then
    return 0
  fi
  curl -s -o /dev/null -X DELETE \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/${release_id}"
}

# 添加错误处理函数
handle_error() {
  log_error "脚本执行失败，行号: $1"
  exit 1
}

# 设置错误处理陷阱
trap 'handle_error $LINENO' ERR

log_info "开始处理新版本..."

# 检查 GITHUB_TOKEN 是否设置
if [ -z "$GITHUB_TOKEN" ]; then
  log_error "GITHUB_TOKEN 未设置。"
  exit 1
fi

# 读取版本列表
if [ ! -f "new_versions.txt" ]; then
  log_error "new_versions.txt 文件未找到。请先运行 get_new_versions.sh。"
  exit 1
fi

# 读取版本列表到数组
mapfile -t VERSION_ARRAY < new_versions.txt
log_info "找到 ${#VERSION_ARRAY[@]} 个需要处理的版本"

# 记录成功和失败的版本
successful_versions=()
failed_versions=()

# 遍历版本列表
for VERSION in "${VERSION_ARRAY[@]}"; do
  log_info "----------------------------------------"
  log_info "处理版本：$VERSION"

  # 检查远程是否已存在该版本标签（已发布的 Release 会创建标签），防止重复处理
  if git ls-remote --tags "https://github.com/${GITHUB_REPOSITORY}.git" "refs/tags/v$VERSION" | grep -q .; then
    log_info "版本 v$VERSION 已发布，跳过。"
    continue
  fi

  # 生成语言包
  log_info "为版本 $VERSION 生成语言包..."
  chmod +x ./build.sh
  if ! ./build.sh "$VERSION"; then
    log_error "版本 $VERSION 的语言包生成失败"
    failed_versions+=("$VERSION")
    continue
  fi

  ZIP_NAME="build-$VERSION.zip"
  if [ ! -f "$ZIP_NAME" ]; then
    log_error "语言包 $ZIP_NAME 未找到，生成可能失败，跳过此版本。"
    failed_versions+=("$VERSION")
    continue
  fi

  # 创建 GitHub Release（草稿模式，标签留到发布成功时由 GitHub 创建）
  log_info "为版本 $VERSION 准备 GitHub Release..."
  
  # 获取上游版本的详细信息，用于丰富我们的Release描述
  UPSTREAM_RELEASE_INFO=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/git-for-windows/git/releases/tags/v$VERSION")
  
  # 提取上游版本的发布日期和URL
  UPSTREAM_RELEASE_DATE=$(echo "$UPSTREAM_RELEASE_INFO" | jq -r '.published_at' | cut -d'T' -f1)
  UPSTREAM_RELEASE_URL=$(echo "$UPSTREAM_RELEASE_INFO" | jq -r '.html_url')
  
  # 生成美化的Release描述
  RELEASE_BODY=$(cat <<EOF
### ℹ️ 信息
- **原版发布日期**: $UPSTREAM_RELEASE_DATE
- **自动构建时间**: $(date +"%Y-%m-%d")
- **适用版本**: Git for Windows v$VERSION

### 📖 使用说明
请参考[项目README](https://github.com/$GITHUB_REPOSITORY#readme)获取详细的安装和使用说明。

### 🔗 相关链接
- [原版发布页面]($UPSTREAM_RELEASE_URL)
- [本项目GitHub仓库](https://github.com/$GITHUB_REPOSITORY)

---
*此语言包由自动构建脚本生成*
EOF
)

  # 判断是否为预发布(RC)版本，避免 RC 语言包在 Releases 页面混入正式版
  if [[ "$VERSION" == *-rc* ]]; then
    IS_PRERELEASE=true
    log_info "版本 $VERSION 为预发布(RC)版本，标记为 prerelease"
  else
    IS_PRERELEASE=false
  fi

  # 1) 创建草稿 Release：draft=true 不会创建 Git 标签，标签仅在最终发布成功时
  #    才由 GitHub 创建。因此中途任何失败都不残留标签，下次定时任务会重新
  #    检测并处理该版本（自愈，避免推标签后失败导致版本被永久跳过）。
  RELEASE_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d @- "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases" <<EOF
{
  "tag_name": "v$VERSION",
  "name": "Git for Windows v$VERSION 中文语言包",
  "body": $(echo "$RELEASE_BODY" | jq -sR .),
  "draft": true,
  "prerelease": $IS_PRERELEASE
}
EOF
  )

  RELEASE_ID=$(echo "$RELEASE_RESPONSE" | jq -r '.id')
  UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | jq -r '.upload_url' | sed 's/{?name,label}//')

  if [ -z "$RELEASE_ID" ] || [ "$RELEASE_ID" = "null" ] || [ -z "$UPLOAD_URL" ] || [ "$UPLOAD_URL" = "null" ]; then
    log_error "创建草稿 Release v$VERSION 失败，跳过此版本。"
    log_error "API 响应：$RELEASE_RESPONSE"
    failed_versions+=("$VERSION")
    continue
  fi

  # 2) 上传语言包资产到草稿 Release
  log_info "上传语言包文件 $ZIP_NAME 到草稿 Release..."
  UPLOAD_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/zip" \
    --data-binary @"$ZIP_NAME" \
    "$UPLOAD_URL?name=$(basename "$ZIP_NAME")")

  if ! echo "$UPLOAD_RESPONSE" | jq -e '.state == "uploaded"' &>/dev/null \
     && ! echo "$UPLOAD_RESPONSE" | jq -e '.url' &>/dev/null; then
    log_error "上传资产到 Release v$VERSION 失败，删除草稿以便下次重试。"
    log_error "API 响应：$UPLOAD_RESPONSE"
    delete_release "$RELEASE_ID" || true
    failed_versions+=("$VERSION")
    continue
  fi

  # 3) 发布 Release（draft=false），此时 GitHub 才创建对应 Git 标签
  PUBLISH_RESPONSE=$(curl -s -X PATCH -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"draft": false}' \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/${RELEASE_ID}")

  if ! echo "$PUBLISH_RESPONSE" | jq -e '.draft == false' &>/dev/null; then
    log_error "发布 Release v$VERSION 失败，删除草稿以便下次重试。"
    log_error "API 响应：$PUBLISH_RESPONSE"
    delete_release "$RELEASE_ID" || true
    failed_versions+=("$VERSION")
    continue
  fi

  log_success "Release v$VERSION 及其资产已发布。"
  successful_versions+=("$VERSION")

  # 清理生成的文件
  log_info "清理版本 $VERSION 的临时文件..."
  rm -f "$ZIP_NAME"
  rm -rf "git-$VERSION"
  rm -f "v$VERSION.tar.gz"

  log_success "版本 v$VERSION 处理完成。"
done

log_info "----------------------------------------"
log_info "所有版本处理摘要："
log_info "成功处理的版本: ${#successful_versions[@]}"
if [ ${#successful_versions[@]} -gt 0 ]; then
  log_success "成功的版本列表: ${successful_versions[*]}"
fi

log_info "失败处理的版本: ${#failed_versions[@]}"
if [ ${#failed_versions[@]} -gt 0 ]; then
  log_error "失败的版本列表: ${failed_versions[*]}"
fi

log_info "所有版本处理完毕。"

# 将处理结果写入GitHub Actions输出
echo "successful_versions=${successful_versions[*]}" >> "$GITHUB_OUTPUT"
echo "failed_versions=${failed_versions[*]}" >> "$GITHUB_OUTPUT"
echo "total_success=${#successful_versions[@]}" >> "$GITHUB_OUTPUT"
echo "total_failed=${#failed_versions[@]}" >> "$GITHUB_OUTPUT"
