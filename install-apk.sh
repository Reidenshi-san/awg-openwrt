#!/bin/sh
set -e

# =========================
# AmneziaWG installer (apk)
# =========================

# ===== базовые проверки =====
command -v apk >/dev/null 2>&1 || {
    echo "❌ apk not found — this script is for OpenWrt 25+"
    exit 1
}

# ===== определение версии OpenWrt =====
. /etc/openwrt_release || {
    echo "❌ Cannot determine OpenWrt version"
    exit 1
}

TAG="v$DISTRIB_RELEASE"
REPO="Reidenshi-san/awg-openwrt"
BASE="https://github.com/$REPO/releases/download/$TAG"

ARCH="mediatek_filogic"

echo "== AmneziaWG installer =="
echo "OpenWrt version: $DISTRIB_RELEASE"
echo "Release tag:     $TAG"
echo "Architecture:   $ARCH"
echo

# ===== защита от неподходящего устройства =====
grep -qi mediatek /proc/cpuinfo || {
    echo "❌ This script is intended for MediaTek devices only"
    exit 1
}

cd /tmp

# ===== пакеты (ВАЖЕН ПОРЯДОК) =====
PKGS="
kmod-amneziawg_${TAG}__${ARCH}.apk
amneziawg-tools_${TAG}__${ARCH}.apk
luci-proto-amneziawg_${TAG}__${ARCH}.apk
luci-i18n-amneziawg-ru_${TAG}__${ARCH}.apk
"

# ===== обновление индекса пакетов =====
echo "== Updating package index =="
apk update

# ===== загрузка пакетов =====
for p in $PKGS; do
    echo "--- Downloading $p"
    wget "$BASE/$p" || {
        echo "❌ Failed to download $p"
        echo "Check that release $TAG exists and contains required files"
        exit 1
    }
done

# ===== установка пакетов (строго по порядку) =====
for p in $PKGS; do
    echo "--- Installing $p"
    apk add --allow-untrusted "$p"
done

# ===== загрузка kernel module =====
modprobe amneziawg || true

echo
echo "✅ AmneziaWG installed successfully"
echo
echo "⚠️  A reboot is required for AmneziaWG to appear in LuCI network interfaces."
echo "    Without reboot, AmneziaWG will NOT be visible or configurable in LuCI."
echo

# ===== интерактивный запрос на перезагрузку =====
printf "🔄 Reboot router now? [y/N]: "
read ANSWER

case "$ANSWER" in
    y|Y|yes|YES)
        echo "⏳ Rebooting in 5 seconds..."
        sleep 5
        reboot
        ;;
    *)
        echo
        echo "ℹ️  Please reboot the router manually later to activate AmneziaWG in LuCI:"
        echo "    reboot"
        ;;
esac
