#!/bin/sh
# AmneziaWG installer for OpenWrt (MediaTek Filogic)
set -e

# --- Цвета (поддержка ANSI только там, где есть) ---
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors)" -ge 8 ]; then
    GREEN="$(tput setaf 2)"
    RED="$(tput setaf 1)"
    BLUE="$(tput setaf 4)"
    NC="$(tput sgr0)"
else
    GREEN=""
    RED=""
    BLUE=""
    NC=""
fi

echo "== AmneziaWG installer =="

# --- OpenWrt информация ---
OPENWRT_VERSION=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d\' -f2)
OPENWRT_TARGET=$(grep DISTRIB_TARGET /etc/openwrt_release | cut -d\' -f2)
ARCH=$(grep DISTRIB_ARCH /etc/openwrt_release | cut -d\' -f2)

case "$OPENWRT_VERSION" in
  v*) RELEASE_TAG="$OPENWRT_VERSION" ;;
  *)  RELEASE_TAG="v$OPENWRT_VERSION" ;;
esac

echo "OpenWrt version: $OPENWRT_VERSION"
echo "Release tag:     $RELEASE_TAG"
echo "Architecture:    $ARCH"
echo "Target:          $OPENWRT_TARGET"
echo

if [ "$OPENWRT_TARGET" != "mediatek/filogic" ]; then
    echo "❌ This script is intended for MediaTek Filogic devices only."
    exit 1
fi
echo "✅ MediaTek Filogic detected"

if apk info kmod-amneziawg >/dev/null 2>&1; then
    echo "⚠️  AmneziaWG уже установлена. Пропускаем установку пакетов."
    exit 0
fi

RELEASE_URL="https://github.com/Reidenshi-san/awg-openwrt/releases/download/$RELEASE_TAG"

PACKAGES="
kmod-amneziawg
amneziawg-tools
luci-proto-amneziawg
luci-i18n-amneziawg-ru
"

TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# --- Spinner (BusyBox safe) ---
spinner() {
    local pid=$1
    local spinstr='|/-\'
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 3); do
            echo -ne "\b${spinstr:$i:1}"
            sleep 1
        done
    done
    echo -ne "\b"
}

download_with_spinner() {
    local url="$1"
    local out="$2"
    wget -q "$url" -O "$out" &
    pid=$!
    echo -n "${BLUE}⬇ Downloading ${out} ${NC}|"
    spinner $pid
    wait $pid
    echo -e " ${GREEN}✅${NC}"
}

install_with_spinner() {
    local apk_file="$1"
    local pkg_name="$2"
    apk add --allow-untrusted "$apk_file" >/dev/null 2>&1 &
    pid=$!
    echo -n "${BLUE}🔄 Installing ${pkg_name} ${NC}|"
    spinner $pid
    wait $pid
    if [ $? -eq 0 ]; then
        echo -e " ${GREEN}✅${NC}"
    else
        echo -e " ${RED}❌${NC}"
    fi
}

APK_FILES=""
FOUND_ANY=0

# --- Обновляем индексы пакетов для подтягивания зависимостей ---
echo "== Updating package index =="
apk update

echo "== Resolving packages =="
for pkg in $PACKAGES; do
    FILE1="${pkg}_${OPENWRT_VERSION}__mediatek_filogic.apk"
    FILE2="${pkg}_v${OPENWRT_VERSION}__mediatek_filogic.apk"

    if wget --spider "$RELEASE_URL/$FILE1" >/dev/null 2>&1; then
        FILE="$FILE1"
    elif wget --spider "$RELEASE_URL/$FILE2" >/dev/null 2>&1; then
        FILE="$FILE2"
    else
        echo "⚠️  $pkg: not found in release $RELEASE_TAG. Skipping."
        continue
    fi

    FOUND_ANY=1
    download_with_spinner "$RELEASE_URL/$FILE" "$TMPDIR/$FILE"
    install_with_spinner "$TMPDIR/$FILE" "$pkg"
    APK_FILES="$APK_FILES $TMPDIR/$FILE"
done

if [ "$FOUND_ANY" -eq 0 ]; then
    echo "❌ No compatible packages found in release $RELEASE_TAG"
    exit 1
fi

echo
echo "✅ AmneziaWG installed successfully"
echo
echo "⚠️  A reboot is required for AmneziaWG to appear in LuCI network interfaces."
echo "    Without reboot, AmneziaWG will NOT be visible or configurable in LuCI."
echo

read -p "🔄 Reboot router now? [y/N]: " answer
case "$answer" in
    y|Y)
        echo "⏳ Rebooting in 5 seconds..."
        sleep 5
        reboot
        ;;
    *)
        echo "Reboot skipped. Cleaning up temporary files..."
        cleanup
        ;;
esac
