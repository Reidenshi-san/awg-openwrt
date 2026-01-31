#!/bin/sh
# AmneziaWG installer for OpenWrt (MediaTek Filogic)

set -e

echo "== AmneziaWG installer =="

# -------------------------------
# Получаем информацию о системе
# -------------------------------
OPENWRT_VERSION=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d\' -f2)
OPENWRT_TARGET=$(grep DISTRIB_TARGET /etc/openwrt_release | cut -d\' -f2)
ARCH=$(grep DISTRIB_ARCH /etc/openwrt_release | cut -d\' -f2)
RELEASE_TAG="v$OPENWRT_VERSION"

echo "OpenWrt version: $OPENWRT_VERSION"
echo "Release tag:     $RELEASE_TAG"
echo "Architecture:    $ARCH"
echo "Target:          $OPENWRT_TARGET"
echo

# -------------------------------
# Проверка таргета
# -------------------------------
if [ "$OPENWRT_TARGET" != "mediatek/filogic" ]; then
    echo "❌ This script is intended for MediaTek Filogic devices only."
    exit 1
fi
echo "✅ MediaTek Filogic detected"

# -------------------------------
# Проверка установки AmneziaWG
# -------------------------------
if apk info kmod-amneziawg >/dev/null 2>&1; then
    echo "⚠️  AmneziaWG уже установлена. Пропускаем установку пакетов."
    exit 0
fi

# -------------------------------
# Проверка существования релиза
# -------------------------------
echo "== Checking if release $RELEASE_TAG exists..."
RELEASE_URL="https://github.com/Reidenshi-san/awg-openwrt/releases/download/$RELEASE_TAG"
APK_CHECK="$RELEASE_URL/kmod-amneziawg_${OPENWRT_VERSION}__mediatek_filogic.apk"
if ! wget --spider "$APK_CHECK" >/dev/null 2>&1; then
    echo "❌ Release $RELEASE_TAG not found. Aborting."
    exit 1
fi

# -------------------------------
# Обновление индекса пакетов
# -------------------------------
echo "== Updating package index =="
apk update

# -------------------------------
# Пакеты для установки
# -------------------------------
PACKAGES="
kmod-amneziawg
amneziawg-tools
luci-proto-amneziawg
luci-i18n-amneziawg-ru
"

APK_FILES=""

# -------------------------------
# Функции для скачивания и установки
# -------------------------------
download_and_install() {
    pkg="$1"
    APK_NAME="${pkg}_${OPENWRT_VERSION}__mediatek_filogic.apk"

    # Скачиваем, если нет файла
    if [ ! -f "$APK_NAME" ]; then
        echo "--- Downloading $APK_NAME"
        if ! wget -q --show-progress "$RELEASE_URL/$APK_NAME" -O "$APK_NAME"; then
            echo "❌ Failed to download $APK_NAME. Aborting."
            exit 1
        fi
        echo "✅ Downloaded $APK_NAME"
    else
        echo "--- $APK_NAME already exists, skipping download"
    fi

    # Установка пакета
    echo "--- Installing $APK_NAME"
    if ! apk add --allow-untrusted "$APK_NAME"; then
        echo "❌ Failed to install $APK_NAME. Aborting."
        exit 1
    fi
    echo "✅ Installed $APK_NAME"

    # Добавляем в список для возможной очистки
    APK_FILES="$APK_FILES $APK_NAME"
}

# -------------------------------
# Основной цикл установки
# -------------------------------
for pkg in $PACKAGES; do
    download_and_install "$pkg"
done

echo
echo "✅ AmneziaWG installed successfully"
echo
echo "⚠️  A reboot is required for AmneziaWG to appear in LuCI network interfaces."
echo "    Without reboot, AmneziaWG will NOT be visible or configurable in LuCI."
echo

# -------------------------------
# Запрос перезагрузки
# -------------------------------
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
            if [ -f "$file" ]; then
                rm -f "$file"
                echo "🗑️  Removed $file"
            fi
        done
        echo "✅ Cleanup done. You can reboot manually later."
        ;;
esac
