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

# 添加错误处理函数
handle_error() {
  log_error "脚本执行失败，行号: $1"
  exit 1
}

# 设置错误处理陷阱
trap 'handle_error $LINENO' ERR

log_info "开始检查新版本..."

# 检查 GITHUB_TOKEN 是否设置
if [ -z "$GITHUB_TOKEN" ]; then
  log_error "GITHUB_TOKEN 未设置。"
  exit 1
fi

UPSTREAM_REPO="git-for-windows/git"
LOCAL_REPO="$GITHUB_REPOSITORY"

# 获取本地仓库已发布的版本
log_info "获取本地仓库已发布的Releases..."
LOCAL_RELEASES_JSON=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$LOCAL_REPO/releases?per_page=100")

# 提取所有Release的名称中包含的版本号
# 由于我们的Release格式是"Git for Windows v版本号 中文语言包"
LOCAL_PROCESSED_VERSIONS=$(echo "$LOCAL_RELEASES_JSON" | jq -r '.[].name' | grep -o "v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.windows\.[0-9][0-9]*" | sed 's/^v//')

# 获取上游仓库的发布版本
log_info "从上游仓库获取发布版本..."
UPSTREAM_RELEASES_JSON=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$UPSTREAM_REPO/releases?per_page=100")

# 检查API调用是否成功
if [ -z "$UPSTREAM_RELEASES_JSON" ] || echo "$UPSTREAM_RELEASES_JSON" | jq -e 'has("message")' > /dev/null; then
  log_error "无法从上游仓库获取版本。请检查GITHUB_TOKEN和网络连接。"
  log_error "API响应: $UPSTREAM_RELEASES_JSON"
  exit 1
fi

# 从JSON响应中提取所有tag名称（按发布日期降序排列），并去掉前缀'v'
UPSTREAM_RELEASES=$(echo "$UPSTREAM_RELEASES_JSON" | \
  jq -r 'sort_by(.published_at) | reverse | .[].tag_name' | \
  sed 's/^v//')

# 计算未处理的版本
log_info "计算未处理的版本..."
NEW_VERSIONS=()
NEW_VERSIONS_INFO=()

# 获取所有版本号及其发布日期
for VERSION in $UPSTREAM_RELEASES; do
  # 检查此版本是否已在本地发布
  if ! echo "$LOCAL_PROCESSED_VERSIONS" | grep -q "^$VERSION$"; then
    # 查找此版本的发布日期
    RELEASE_DATE=$(echo "$UPSTREAM_RELEASES_JSON" | jq -r --arg tag "v$VERSION" '.[] | select(.tag_name == $tag) | .published_at' | cut -d'T' -f1)
    NEW_VERSIONS+=("$VERSION")
    NEW_VERSIONS_INFO+=("$VERSION (发布于: $RELEASE_DATE)")
  fi
done

# 将新版本列表保存到文件，并设置输出变量
if [ ${#NEW_VERSIONS[@]} -eq 0 ]; then
  log_info "没有新版本需要处理。"
  echo "has_new_versions=false" >> "$GITHUB_OUTPUT"
else
  log_info "发现 ${#NEW_VERSIONS[@]} 个新版本需要处理："
  for VERSION_INFO in "${NEW_VERSIONS_INFO[@]}"; do
    log_info "  - $VERSION_INFO"
  done
  
  # 只保存版本号到文件中，不保存额外信息
  printf "%s\n" "${NEW_VERSIONS[@]}" > new_versions.txt
  echo "has_new_versions=true" >> "$GITHUB_OUTPUT"
  echo "new_versions_count=${#NEW_VERSIONS[@]}" >> "$GITHUB_OUTPUT"
fi

log_info "新版本检查完成。"
