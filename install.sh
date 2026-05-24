#!/usr/bin/env bash
# install.sh — system setup for myCoolMachine
# Run once on a fresh LinuxCNC ISO install.
# The LinuxCNC ISO already provides: linuxcnc-uspace, PREEMPT_RT kernel.
# This script adds: IgH EtherCAT master, linuxcnc-ethercat, system tuning.
#
# Usage:
#   ETHERCAT_IF=enp3s0 bash install.sh
#   or run without ETHERCAT_IF and you will be prompted.
set -euo pipefail

# ── Versions — verify these before running on a new machine ──────────────────
IGH_VERSION="1.6.9"
IGH_URL="https://gitlab.com/etherlab.org/ethercat/-/archive/${IGH_VERSION}/ethercat-${IGH_VERSION}.tar.gz"

# Check https://github.com/linuxcnc-ethercat/linuxcnc-ethercat/releases for latest
LCEC_VERSION="1.41.1"
LCEC_DEB_URL="https://github.com/linuxcnc-ethercat/linuxcnc-ethercat/releases/download/v${LCEC_VERSION}/linuxcnc-ethercat_${LCEC_VERSION}_amd64.deb"

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="/tmp/igh-ethercat-${IGH_VERSION}"

# ── Preflight ─────────────────────────────────────────────────────────────────
if [[ -z "${ETHERCAT_IF:-}" ]]; then
    echo "Available network interfaces:"
    ip -br link | grep -v lo
    echo
    read -rp "Enter the EtherCAT network interface (NOT your main LAN port): " ETHERCAT_IF
fi

if [[ $EUID -ne 0 ]]; then
    exec sudo ETHERCAT_IF="$ETHERCAT_IF" SUDO_USER="$USER" "$0" "$@"
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

echo "=== myCoolMachine install ==="
echo "EtherCAT interface : $ETHERCAT_IF"
echo "IgH version        : $IGH_VERSION"
echo "lcec version       : $LCEC_VERSION"
echo "Config user        : $REAL_USER"
echo

# ── Build dependencies ────────────────────────────────────────────────────────
echo "--- Installing build dependencies ---"
apt-get update -qq
apt-get install -y \
    build-essential autoconf automake libtool \
    "linux-headers-$(uname -r)" \
    wget git

# ── Disable automatic updates ─────────────────────────────────────────────────
echo "--- Disabling automatic updates ---"
systemctl disable --now unattended-upgrades 2>/dev/null || true
systemctl disable --now packagekit         2>/dev/null || true
systemctl mask packagekit-offline-update   2>/dev/null || true
apt-get remove -y --purge unattended-upgrades 2>/dev/null || true

# ── CPU low-latency (persistent via grub) ────────────────────────────────────
echo "--- Configuring grub for low-latency RT ---"
GRUB_FILE=/etc/default/grub
GRUB_OPTS='quiet processor.max_cstate=1 intel_idle.max_cstate=1 cpufreq.default_governor=performance'
if ! grep -q "max_cstate" "$GRUB_FILE"; then
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"${GRUB_OPTS}\"/" "$GRUB_FILE"
    update-grub
    echo "Grub updated — reboot for CPU settings to take effect."
else
    echo "Grub already configured, skipping."
fi

# Apply for this session without reboot
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > "$f" 2>/dev/null || true
done
for f in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
    echo 1 > "$f" 2>/dev/null || true
done

# ── IgH EtherCAT master ───────────────────────────────────────────────────────
if command -v ethercat &>/dev/null && ethercat version 2>/dev/null | grep -q "$IGH_VERSION"; then
    echo "--- IgH EtherCAT master ${IGH_VERSION} already installed, skipping ---"
else
    echo "--- Building IgH EtherCAT master ${IGH_VERSION} ---"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    wget -q --show-progress "$IGH_URL" -O ethercat.tar.gz
    tar xzf ethercat.tar.gz --strip-components=1
    ./bootstrap
    ./configure \
        --prefix=/usr/local \
        --sysconfdir=/etc \
        --enable-generic \
        --disable-8139too \
        --disable-e100 \
        --disable-e1000 \
        --disable-e1000e \
        --disable-r8169 \
        --disable-r8152 \
        --disable-cx2100
    make -j"$(nproc)"
    make install
    ldconfig
    echo "IgH EtherCAT master installed."
fi

# ── Configure EtherCAT interface ─────────────────────────────────────────────
echo "--- Configuring /etc/ethercat.conf ---"
MAC=$(ip link show "$ETHERCAT_IF" 2>/dev/null | awk '/link\/ether/{print $2}')
if [[ -z "$MAC" ]]; then
    echo "ERROR: could not find MAC address for interface '$ETHERCAT_IF'"
    echo "Check the interface name with: ip link"
    exit 1
fi
cat > /etc/ethercat.conf <<EOF
MASTER0_DEVICE="$MAC"
DEVICE_MODULES="generic"
EOF
echo "  Interface: $ETHERCAT_IF  MAC: $MAC"

systemctl enable ethercat
systemctl restart ethercat
echo "EtherCAT master service started."

# ── udev rule for /dev/ethercat ───────────────────────────────────────────────
echo "--- Installing udev rule for /dev/ethercat ---"
cp "$REPO_DIR/udev/99-ethercat.rules" /etc/udev/rules.d/
udevadm control --reload-rules
udevadm trigger --name-match=ethercat
echo "udev rule installed."

# ── linuxcnc-ethercat ─────────────────────────────────────────────────────────
if dpkg -l linuxcnc-ethercat 2>/dev/null | grep -q "^ii"; then
    echo "--- linuxcnc-ethercat already installed, skipping ---"
else
    echo "--- Installing linuxcnc-ethercat ${LCEC_VERSION} ---"
    TMP_DEB="/tmp/linuxcnc-ethercat.deb"
    wget -q --show-progress "$LCEC_DEB_URL" -O "$TMP_DEB"
    dpkg -i "$TMP_DEB"
    rm -f "$TMP_DEB"
    echo "linuxcnc-ethercat installed."
fi

# ── Deploy machine config ─────────────────────────────────────────────────────
echo "--- Deploying machine configuration ---"
sudo -u "$REAL_USER" bash "$REPO_DIR/deploy.sh"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo "=== Install complete ==="
echo
echo "Next steps:"
echo "  1. Reboot to apply grub CPU settings"
echo "  2. Run 'latency-test' for a few minutes and confirm max jitter < 50us"
echo "  3. Start LinuxCNC and verify EtherCAT master connects to drive"
