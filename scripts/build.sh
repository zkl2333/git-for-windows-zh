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

# 添加错误处理函数
handle_error() {
  log_error "脚本执行失败，行号: $1"
  exit 1
}

# 设置错误处理陷阱
trap 'handle_error $LINENO' ERR

# 检查是否提供了git版本参数
if [ -z "$1" ]; then
  log_error "用法：$0 <git版本>"
  exit 1
fi

gitver="$1"
tarfile="v$gitver.tar.gz"
dir="git-$gitver"
outdir="build"

log_info "开始为版本 $gitver 构建语言包..."

# 如果tarball不存在，则下载
if [ ! -f "$tarfile" ]; then
  log_info "下载 Git 源代码 v$gitver..."
  if ! curl -L -o "$tarfile" "https://github.com/git-for-windows/git/archive/refs/tags/$tarfile"; then
    log_error "下载源码失败"
    exit 1
  fi
  log_success "源码下载完成"
fi

# 解压tarball
log_info "解压源代码..."
if ! tar xf "$tarfile"; then
  log_error "解压源码失败"
  exit 1
fi
log_success "源码解压完成"

# 检查po文件是否存在
if [ ! -f "$dir/po/zh_CN.po" ]; then
  log_error "未找到翻译文件 $dir/po/zh_CN.po"
  exit 1
fi

if [ ! -f "$dir/git-gui/po/zh_cn.po" ]; then
  log_error "未找到翻译文件 $dir/git-gui/po/zh_cn.po"
  exit 1
fi

if [ ! -f "$dir/gitk-git/po/zh_cn.po" ]; then
  log_error "未找到翻译文件 $dir/gitk-git/po/zh_cn.po"
  exit 1
fi

# 定义本地化目录
modir="$outdir/mingw64/share/locale/zh_CN/LC_MESSAGES"
guidir="$outdir/mingw64/share/git-gui/lib/msgs"
gitkdir="$outdir/mingw64/share/gitk/lib/msgs"

# 创建必要的目录
log_info "创建输出目录结构..."
mkdir -p "$modir" "$guidir" "$gitkdir"

# 编译本地化文件
log_info "编译本地化文件..."
log_info "编译 git.mo..."
if ! msgfmt -o "$modir/git.mo" "$dir/po/zh_CN.po"; then
  log_error "编译 git.mo 失败"
  exit 1
fi

log_info "编译 git-gui 本地化文件..."
if ! msgfmt --tcl -l zh_CN -d "$guidir" "$dir/git-gui/po/zh_cn.po"; then
  log_error "编译 git-gui 本地化文件失败"
  exit 1
fi

log_info "编译 gitk 本地化文件..."
if ! msgfmt --tcl -l zh_CN -d "$gitkdir" "$dir/gitk-git/po/zh_cn.po"; then
  log_error "编译 gitk 本地化文件失败"
  exit 1
fi

zipname="build-$gitver.zip"

# 如果存在旧的zip文件，删除它
[ -f "$zipname" ] && rm -f "$zipname"

# 创建zip归档
log_info "创建zip归档文件 $zipname..."
# 检查是否有zip命令
if ! command -v zip >/dev/null 2>&1; then
  log_error "未找到zip命令，请安装zip工具包"
  exit 1
fi

# 使用zip命令创建归档
(
  cd "$outdir" || exit 1
  if ! zip -r -y "../$zipname" .; then
    log_error "使用zip命令创建归档失败"
    exit 1
  fi
)

# 验证zip文件是否创建成功
if [ ! -f "$zipname" ]; then
  log_error "未能成功创建zip文件 $zipname"
  exit 1
fi

# 检查zip文件大小
zipsize=$(du -k "$zipname" | cut -f1)
if [ "$zipsize" -lt 10 ]; then  # 小于10KB的文件可能是空的或损坏的
  log_error "创建的zip文件太小($zipsize KB)，可能损坏"
  exit 1
fi

log_success "成功创建zip归档文件：$zipname (${zipsize}KB)"

# 清理
log_info "清理临时文件..."
rm -rf "$outdir" "$dir"
# 保留tar.gz文件以备后续版本检查使用

log_success "语言包 $zipname 构建完成！"
exit 0
