#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

version=1.14.4
work_dir=/etc/sing-box
binary="$work_dir/sing-box"
library="$work_dir/libcronet.so"
service=sing-box.service

if [[ $(uname -s) != Linux || $EUID != 0 ]]; then
  printf '请在 Linux VPS 上以 root 运行。\n' >&2
  exit 1
fi
for tool in systemctl curl sha256sum tar flock; do
  command -v "$tool" >/dev/null || { printf '缺少命令：%s\n' "$tool" >&2; exit 1; }
done
case "$(uname -m)" in
  x86_64) arch=amd64; digest=699a1b510aa4396b2176d32d1181920399ebf1e267835da6f3b598d0f7c24968 ;;
  aarch64) arch=arm64; digest=436441f76ee2f7fe21b5b2d426d3cb261a480455a704865789ad533e4273ec26 ;;
  *) printf '此升级脚本支持 Linux amd64 和 arm64。\n' >&2; exit 1 ;;
esac

exec 9>/run/lock/kyong-sing-box-upgrade.lock
flock -n 9 || { printf '已有 sing-box 升级正在运行。\n' >&2; exit 1; }
exec_start=$(systemctl show -p ExecStart --value "$service")
if [[ $exec_start != "{ path=$binary ; argv[]=$binary run -C $work_dir/conf ; "* &&
      $exec_start != "{ path=$binary ; argv[]=$binary run -C $work_dir/conf/ ; "* ]]; then
  printf '未找到菜单 2 安装的 sing-box 服务，升级已停止。\n' >&2
  exit 1
fi
if [[ ! -f $binary || -L $binary || ! -d $work_dir/conf ||
      -L $library || ( -e $library && ! -f $library ) ]]; then
  printf '现有内核或配置路径不符合升级条件。\n' >&2
  exit 1
fi
systemctl is-active --quiet "$service" || {
  printf '请先启动现有 sing-box 服务，再执行升级。\n' >&2
  exit 1
}

archive_dir="sing-box-$version-linux-$arch"
stage=$(mktemp -d "$work_dir/.upgrade-$version.XXXXXXXX")
backup=
applying=0
had_library=0
cleanup() {
  local status=$?
  trap - EXIT INT TERM HUP
  if (( applying )); then
    printf '升级失败，正在恢复旧内核。备份：%s\n' "$backup" >&2
    if (( had_library )); then
      cp -p -- "$backup/libcronet.so" "$stage/restore-lib" &&
        mv -fT -- "$stage/restore-lib" "$library" || status=1
    elif [[ -f $library ]]; then
      unlink "$library" || status=1
    fi
    cp -p -- "$backup/sing-box" "$stage/restore-bin" &&
      mv -fT -- "$stage/restore-bin" "$binary" &&
      systemctl restart "$service" || {
        printf '自动恢复失败，请用备份目录恢复内核并检查服务。\n' >&2
        status=1
      }
  fi
  for item in package.tar.gz sing-box libcronet.so restore-bin restore-lib; do
    if [[ -f $stage/$item ]]; then unlink "$stage/$item" || true; fi
  done
  rmdir "$stage" || true
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

curl -q -fsSL --retry 3 --proto '=https' --proto-redir '=https' \
  "https://github.com/SagerNet/sing-box/releases/download/v$version/$archive_dir.tar.gz" \
  -o "$stage/package.tar.gz"
printf '%s  %s\n' "$digest" "$stage/package.tar.gz" | sha256sum -c -
for item in sing-box libcronet.so; do
  tar -xOf "$stage/package.tar.gz" "$archive_dir/$item" > "$stage/$item"
done
chmod 0755 "$stage/sing-box"
chmod 0644 "$stage/libcronet.so"
reported=$("$stage/sing-box" version)
if [[ ${reported%%$'\n'*} != "sing-box version $version" ]]; then
  printf '下载的内核未报告目标版本。\n' >&2
  exit 1
fi
(cd "$work_dir" && "$stage/sing-box" check -C "$work_dir/conf")
if cmp -s "$stage/sing-box" "$binary" && cmp -s "$stage/libcronet.so" "$library"; then
  printf 'sing-box %s 已安装。\n' "$version"
  exit 0
fi

backup=$(mktemp -d "$work_dir/kernel-backup.XXXXXXXX")
cp -p -- "$binary" "$backup/sing-box"
if [[ -f $library ]]; then
  cp -p -- "$library" "$backup/libcronet.so"
  had_library=1
fi
applying=1
mv -fT -- "$stage/libcronet.so" "$library"
mv -fT -- "$stage/sing-box" "$binary"
systemctl restart "$service"
sleep 2
systemctl is-active --quiet "$service"
applying=0
printf 'sing-box 已升级至 %s。旧内核备份：%s\n' "$version" "$backup"
