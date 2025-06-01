#!/bin/ash
# ---------------------------------------------------------------------------
#  河南大学校园网自动登录 (OpenWrt BusyBox 兼容)  –  2025-06-01 修订  GIthub/SnowSwordScholar  MIT License
#
#  使用前请确保你已经仔细阅读本项目文档末的免责声明部分
#
# ---------------------------------------------------------------------------

set -e

# ---------- 可调参数 --------------------------------------------------------
CAPTIVE_TEST_URL="http://detectportal.firefox.com/success.txt"  # 检测是否被劫持的 URL
LOG="/tmp/campus_auth.log"  # 日志文件路径

# 环境变量文件查找顺序：
# 1. 命令行参数 (如果提供)
# 2. 当前目录 .env
# 3. /etc/campus_auth.env
# 4. 脚本所在目录 .env

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 检查命令行参数
if [ -n "$1" ] && [ -f "$1" ]; then
    ENV_FILE="$1"
elif [ -f "./.env" ]; then
    ENV_FILE="./.env"
elif [ -f "/etc/campus_auth.env" ]; then
    ENV_FILE="/etc/campus_auth.env"
else
    ENV_FILE="$SCRIPT_DIR/.env"
fi

# ---------- 工具函数 --------------------------------------------------------
log() {
  if [ "$MODE" = "debug" ]; then
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG"   # 调试模式：输出到终端和日志文件
  else
    echo "[$(date '+%F %T')] $*" >> "$LOG"          # 生产模式：只输出到日志文件
  fi
}

urlencode() { # 简易 urlencode（够用）
  echo -n "$1" | sed -e 's/%/%25/g' -e 's/&/%26/g' -e 's/+/ %2B/g' \
                     -e 's/@/%40/g' -e 's/\//%2F/g' -e 's/:/%3A/g' \
                     -e 's/=/%3D/g' -e 's/?/%3F/g'
}

rand_uuid()   { cat /proc/sys/kernel/random/uuid; }
ms_epoch()    { date +%s%3N; }

# ---------- 读取环境变量配置文件 ---------------------------------------------------------
if [ -f "$ENV_FILE" ]; then
    echo "使用配置文件: $ENV_FILE"
    . "$ENV_FILE"
else
    echo "错误: 找不到配置文件!"
    echo "请在以下位置之一创建配置文件:"
    echo "1. 命令行参数指定的位置"
    echo "2. 当前目录: ./.env"
    echo "3. 系统配置目录: /etc/campus_auth.env"
    echo "4. 脚本所在目录: $SCRIPT_DIR/.env"
    exit 1
fi

: "${USERNAME:?请在 .env 中设置 USERNAME}"
: "${PASSWORD:?请在 .env 中设置 PASSWORD}"
: "${OP_SUFFIX:=@henuyd}"
: "${MODE:=production}"  # 默认为生产模式

# ---------- 判断是否重定向 ---------------------------------------------
detect_captive() {
  hdr_file=$(mktemp)
  curl -s -k -o /dev/null -D "$hdr_file" "$CAPTIVE_TEST_URL"

  status=$(awk '/^HTTP/{code=$2}END{print code}' "$hdr_file")
  location=$(awk 'tolower($1)=="location:"{print $2}' "$hdr_file" | tr -d '\r')

  rm -f "$hdr_file"

  case "$status" in
    30[1-3]|307|308) echo "$location" ;;   # 返回重定向地址 ⇒ 需登录
    *)               echo ""          ;;   # 已在线
  esac
}

# ---------- 解析 portalReceiveAction 参数 ----------------------------------
parse_portal_params() {
  local url="$1"
  wlanuserip=$(echo "$url" | grep -oE 'wlanuserip=[^&]+'  | cut -d= -f2)
  wlanacname=$(echo  "$url" | grep -oE 'wlanacname=[^&]+' | cut -d= -f2)
  portal_host=$(echo  "$url" | cut -d/ -f3)               # 172.29.35.36:6060
  printf '%s|%s|%s\n' "$portal_host" "$wlanuserip" "$wlanacname"
}

# ---------- 从 common.js 抓取 API ------------------------------------------
fetch_api_urls() {
  local host="$1"
  local js; js=$(curl -s -k "http://$host/portal/usertemp_computer/henu-kaifeng-pc/front/js/common.js" || true)

  auth_api=$(  echo "$js" | grep -oE 'authApiUrl *= *"[^"]+"'  | cut -d'"' -f2 )
  check_api=$( echo "$js" | grep -oE 'checkApiUrl *= *"[^"]+"' | cut -d'"' -f2 )

  # fallback：保持旧段的  .27:8088 / .27:8882
  if [ -z "$auth_api" ];  then
      base_ip=$(echo "$host" | awk -F'[.:]' '{printf "%s.%s.%s.27:8088",$1,$2,$3}')
      auth_api="http://$base_ip/aaa-auth/api/v1/auth"
  fi
  if [ -z "$check_api" ]; then
      base_ip=$(echo "$host" | awk -F'[.:]' '{printf "%s.%s.%s.27:8882",$1,$2,$3}')
      check_api="http://$base_ip/user/check-only"
  fi
  printf '%s|%s\n' "$auth_api" "$check_api"
}

# ---------- check-only ------------------------------------------------------
check_only() {
  local url="$1"
  log "→ check-only: $url"
  curl -k -s \
    -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    --data "username=$(urlencode "$USERNAME")&password=$(urlencode "$PASSWORD")&operatorSuffix=$(urlencode "$OP_SUFFIX")" \
    "$url" | tee -a "$LOG"
}

# ---------- auth ------------------------------------------------------------
do_auth() {
  local url="$1" codes="$2"
  log "→ auth: $url"
  curl -k -s \
   -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
   --data "campusCode=$(urlencode "$codes")&username=$(urlencode "$USERNAME")&password=$(urlencode "$PASSWORD")&operatorSuffix=$(urlencode "$OP_SUFFIX")" \
   "$url" | tee -a "$LOG"
}

# ---------- quickauth -------------------------------------------------------
quick_auth() {
  local host="$1" ip="$2" acname="$3"

  local portal_json
  portal_json=$(curl -s -k "http://$host/PortalJsonAction.do?wlanuserip=$ip&wlanacname=$acname&viewStatus=1")
  wlanacIp=$(echo "$portal_json" | grep -oE '"serverip":"[^"]+' | cut -d'"' -f4)

  ts=$(ms_epoch)
  uuid=$(rand_uuid)

  local qurl="http://$host/quickauth.do?userid=$(urlencode "${USERNAME}${OP_SUFFIX}")&passwd=$(urlencode "$PASSWORD")&wlanuserip=$ip&wlanacname=$acname&wlanacIp=$wlanacIp&ssid=&vlan=&mac=&version=0&portalpageid=4&timestamp=$ts&uuid=$uuid&portaltype=0&hostname=&bindCtrlId="

  log "→ quickauth: $qurl"
  curl -k -s \
       -H "Accept: application/json, text/javascript, */*; q=0.01" \
       -H "X-Requested-With: XMLHttpRequest" \
       "$qurl" | tee -a "$LOG"
}

# ---------- 主流程 ----------------------------------------------------------
main() {
  need_login_url=$(detect_captive)

  if [ -z "$need_login_url" ]; then
      log "已在线 (跳过)"
      return 0
  fi

  IFS='|' read -r portal_host wlanuserip wlanacname <<EOF
$(parse_portal_params "$need_login_url")
EOF
  log "捕获门户: $portal_host  ip=$wlanuserip  ac=$wlanacname"

  IFS='|' read -r auth_api check_api <<EOF
$(fetch_api_urls "$portal_host")
EOF
  log "auth_api=$auth_api"
  log "check_api=$check_api"

  # check-only（失败继续）
  check_only "$check_api" || true

  # auth
  school_codes=$(echo "$auth_api" | grep -oE '[a-f0-9]{32},[a-f0-9]{32}' \
                 || echo "92c8c96e4c37100777c7190b76d28233,07cdfd23373b17c6b337251c22b7ea57")
  do_auth "$auth_api" "$school_codes"

  # quickauth
  quick_auth "$portal_host" "$wlanuserip" "$wlanacname"

  # 再检测
  [ -z "$(detect_captive)" ] && log "✔ 认证成功" || log "✘ 仍被劫持"
}

main "$@"
