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

log_info "从本地仓库获取标签..."
# 获取本地仓库的所有标签
LOCAL_TAGS=$(git ls-remote --tags "https://github.com/$LOCAL_REPO.git" | awk -F'/' '{print $NF}' | sed 's/^v//')

log_info "从上游仓库获取发布版本..."
# 获取上游仓库的所有发布版本
UPSTREAM_TAGS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$UPSTREAM_REPO/releases?per_page=100" | jq -r '.[].tag_name | select(test("^v[0-9]+[.][0-9]+[.][0-9]+"))' | sed 's/^v//')

# 检查API调用是否成功
if [ -z "$UPSTREAM_TAGS" ]; then
  log_error "无法从上游仓库获取标签。请检查GITHUB_TOKEN和网络连接。"
  exit 1
fi

# 计算未处理的版本
log_info "计算未处理的版本..."
NEW_VERSIONS=()
for VERSION in $UPSTREAM_TAGS; do
  if ! echo "$LOCAL_TAGS" | grep -q "^$VERSION$"; then
    NEW_VERSIONS+=("$VERSION")
  fi
done

# 将新版本列表保存到文件，并设置输出变量
if [ ${#NEW_VERSIONS[@]} -eq 0 ]; then
  log_info "没有新版本需要处理。"
  echo "has_new_versions=false" >> "$GITHUB_OUTPUT"
else
  log_info "发现 ${#NEW_VERSIONS[@]} 个新版本需要处理：${NEW_VERSIONS[@]}"
  printf "%s\n" "${NEW_VERSIONS[@]}" > new_versions.txt
  echo "has_new_versions=true" >> "$GITHUB_OUTPUT"
fi

log_info "新版本检查完成。"
