#!/bin/sh
# AmneziaWG installer for OpenWrt (MediaTek Filogic)

set -e

echo "== AmneziaWG installer =="

# Получаем информацию о системе
OPENWRT_VERSION=$(cat /etc/openwrt_release | grep DISTRIB_RELEASE | cut -d\' -f2)
OPENWRT_TARGET=$(cat /etc/openwrt_release | grep DISTRIB_TARGET | cut -d\' -f2)
ARCH=$(cat /etc/openwrt_release | grep DISTRIB_ARCH | cut -d\' -f2)
RELEASE_TAG="v$OPENWRT_VERSION"

echo "OpenWrt version: $OPENWRT_VERSION"
echo "Release tag:     $RELEASE_TAG"
echo "Architecture:    $ARCH"
echo "Target:          $OPENWRT_TARGET"
echo

# Проверка таргета
if [ "$OPENWRT_TARGET" != "mediatek/filogic" ]; then
    echo "❌ This script is intended for MediaTek Filogic devices only."
    exit 1
fi
echo "✅ MediaTek Filogic detected"

# Проверка, установлен ли уже AmneziaWG
if apk info kmod-amneziawg >/dev/null 2>&1; then
    echo "⚠️  AmneziaWG уже установлена. Пропускаем установку пакетов."
    exit 0
fi

# Проверка существования релиза на GitHub
echo "== Checking if release $RELEASE_TAG exists..."
RELEASE_URL="https://github.com/Reidenshi-san/awg-openwrt/releases/download/$RELEASE_TAG"
if ! wget --spider "$RELEASE_URL/kmod-amneziawg_${OPENWRT_VERSION}__mediatek_filogic.apk" >/dev/null 2>&1; then
    echo "❌ Release $RELEASE_TAG not found. Aborting."
    exit 1
fi

# Обновление индекса пакетов
echo "== Updating package index =="
apk update

# Скачиваем и устанавливаем пакеты
PACKAGES="
kmod-amneziawg
amneziawg-tools
luci-proto-amneziawg
luci-i18n-amneziawg-ru
"

for pkg in $PACKAGES; do
    APK_NAME="${pkg}_${OPENWRT_VERSION}__mediatek_filogic.apk"
    echo "--- Downloading $APK_NAME"
    wget -q --show-progress "$RELEASE_URL/$APK_NAME" -O "$APK_NAME"

    echo "--- Installing $APK_NAME"
    apk add --allow-untrusted "$APK_NAME"
done

echo
echo "✅ AmneziaWG installed successfully"
echo
echo "⚠️  A reboot is required for AmneziaWG to appear in LuCI network interfaces."
echo "    Without reboot, AmneziaWG will NOT be visible or configurable in LuCI."
echo

read -p "🔄 Reboot router now? [y/N]: " answer
case "$answer" in
    y|Y) echo "⏳ Rebooting in 5 seconds..."
         sleep 5
         reboot
         ;;
    *) echo "Reboot skipped. You can reboot manually later." ;;
esac
