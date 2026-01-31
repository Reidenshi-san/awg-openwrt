#!/bin/sh
# AmneziaWG installer for OpenWrt (MediaTek Filogic)

set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

echo "== AmneziaWG installer =="

OPENWRT_VERSION=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d\' -f2)
OPENWRT_TARGET=$(grep DISTRIB_TARGET /etc/openwrt_release | cut -d\' -f2)
ARCH=$(grep DISTRIB_ARCH /etc/openwrt_release | cut -d\' -f2)
RELEASE_TAG="v$OPENWRT_VERSION"

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

echo "== Checking if release $RELEASE_TAG exists..."
RELEASE_URL="https://github.com/Reidenshi-san/awg-openwrt/releases/download/$RELEASE_TAG"
if ! wget --spider "$RELEASE_URL/kmod-amneziawg_${OPENWRT_VERSION}__mediatek_filogic.apk" >/dev/null 2>&1; then
    echo "❌ Release $RELEASE_TAG not found. Aborting."
    exit 1
fi

echo "== Updating package index =="
apk update

PACKAGES="
kmod-amneziawg
amneziawg-tools
luci-proto-amneziawg
luci-i18n-amneziawg-ru
"

APK_FILES=""

spinner() {
    local pid=$1
    local delay=0.2
    local spinstr='|/-\'
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 3); do
            echo -ne "\b${spinstr:$i:1}"
            sleep $delay
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

for pkg in $PACKAGES; do
    APK_NAME="${pkg}_${OPENWRT_VERSION}__mediatek_filogic.apk"
    download_with_spinner "$RELEASE_URL/$APK_NAME" "$APK_NAME"
    install_with_spinner "$APK_NAME" "$pkg"
    APK_FILES="$APK_FILES $APK_NAME"
done

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
        echo "Reboot skipped. Cleaning up downloaded APKs..."
        for file in $APK_FILES; do
            [ -f "$file" ] && rm -f "$file"
        done
        echo "Cleanup done. You can reboot manually later."
        ;;
esac
