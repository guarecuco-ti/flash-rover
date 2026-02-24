#!/bin/bash
# Quick NBCN flash script for rapid testing
# Flashes NBCN image and optionally FH image for OAD testing
# Skips Factory image to save time

set -e  # Exit on error

export CCS_ROOT=/home/a1244925/ti/ccs1281/ccs
cd /home/a1244925/ti/flash-rover

NBCN_BIN="/home/a1244925/workspace_ccstheia/sensor_oad_offchip_src_LP_CC1312R7_NBCN/Release/sensor_oad_offchip_src_LP_CC1312R7_NBCN.bin"
FH_BIN="/home/a1244925/workspace_ccstheia/sensor_oad_offchip_src_LP_CC1312R7_FH/Release/sensor_oad_offchip_src_LP_CC1312R7_FH.bin"

# Parse arguments
FLASH_FH=true
if [ "$1" = "--nbcn-only" ]; then
    FLASH_FH=false
fi

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Quick NBCN Flash (For OAD Testing)                 ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  Device:      CC1312R7                                     ║"
echo "║  Mode:        NBCN + FH (for OAD target)                   ║"
echo "║  Skip:        Factory image (faster flashing)              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if binaries exist
echo "Checking binary files..."
if [ ! -f "$NBCN_BIN" ]; then
    echo "✗ Error: NBCN binary not found: $NBCN_BIN"
    exit 1
fi
if $FLASH_FH && [ ! -f "$FH_BIN" ]; then
    echo "✗ Error: FH binary not found: $FH_BIN"
    exit 1
fi
echo "✓ Binary files found"
echo ""

# Step 1: Erase only necessary sectors (faster than mass erase)
echo "═══ Step 1: Erase Flash Sectors ═══"
echo "Erasing metadata pages (0x0000-0x4000)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR erase 0 16384 2>&1 | tail -2
echo "Erasing NBCN region (0x36000-0x68000)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR erase 221184 204800 2>&1 | tail -2
if $FLASH_FH; then
    echo "Erasing FH region (0x68000-0x9A000)..."
    ./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR erase 425984 204800 2>&1 | tail -2
fi
echo "Erasing NVS region (0x9A000-0x9B000)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR erase 630784 4096 2>&1 | tail -2
echo "✓ Sectors erased"
echo ""

# Step 2: Create metadata
echo "═══ Step 2: Generate Metadata ═══"
python3 /tmp/create_multiimage_metadata.py > /dev/null
echo "✓ Metadata generated"
echo ""

# Step 3: Flash NBCN image
echo "═══ Step 3: Flash NBCN Image ═══"
echo "Writing to 0x36000 (221184)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 221184 -i "$NBCN_BIN" 2>&1 | tail -3
echo "✓ NBCN image written"
echo ""

# Step 4: Flash NBCN metadata
echo "═══ Step 4: Flash NBCN Metadata ═══"
echo "Writing to Page 2 (0x2000 = 8192)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 8192 -i /tmp/nbcn_metadata.bin 2>&1 | tail -3
echo "✓ NBCN metadata written"
echo ""

# Step 5: Flash FH image and metadata (optional, for OAD testing)
if $FLASH_FH; then
    echo "═══ Step 5: Flash FH Image (OAD Target) ═══"
    echo "Writing to 0x68000 (425984)..."
    ./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 425984 -i "$FH_BIN" 2>&1 | tail -3
    echo "✓ FH image written"
    echo ""

    echo "═══ Step 6: Flash FH Metadata ═══"
    echo "Writing to Page 3 (0x3000 = 12288)..."
    ./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 12288 -i /tmp/fh_metadata.bin 2>&1 | tail -3
    echo "✓ FH metadata written"
    echo ""
    STEP_NUM=7
else
    STEP_NUM=5
fi

# Step N: Write NVS Mode Configuration
echo "═══ Step $STEP_NUM: Write NVS Mode Configuration ═══"
echo "Configuring BIM to boot NBCN..."

# Generate NVS config
python3 /tmp/create_nvs_mode_config.py > /dev/null

# Write NBCN mode config (default)
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 631040 -i /tmp/nvs_mode_nbcn.bin 2>&1 | tail -3
echo "✓ NVS mode set to NBCN"
echo ""

# Verification
STEP_NUM=$((STEP_NUM + 1))
echo "═══ Step $STEP_NUM: Quick Verification ═══"
echo ""
echo "Verifying NBCN metadata (Page 2)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR read 8192 52 --output /tmp/verify_nbcn.bin 2>/dev/null

imgcpstat=$(hexdump -s 0x10 -n 1 -e '1/1 "0x%02x"' /tmp/verify_nbcn.bin)
imgtype=$(hexdump -s 0x12 -n 1 -e '1/1 "0x%02x"' /tmp/verify_nbcn.bin)
imgno=$(hexdump -s 0x13 -n 1 -e '1/1 "0x%02x"' /tmp/verify_nbcn.bin)

echo "  imgCpStat: $imgcpstat (expect 0xfe)"
echo "  imgType:   $imgtype (expect 0x07)"
echo "  imgNo:     $imgno (expect 0x01)"

if [ "$imgtype" = "0x07" ] && [ "$imgno" = "0x01" ] && [ "$imgcpstat" = "0xfe" ]; then
    echo "  ✓ NBCN metadata valid"
else
    echo "  ⚠️  Unexpected metadata values!"
fi

if $FLASH_FH; then
    echo ""
    echo "Verifying FH metadata (Page 3)..."
    ./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR read 12288 52 --output /tmp/verify_fh.bin 2>/dev/null

    imgcpstat=$(hexdump -s 0x10 -n 1 -e '1/1 "0x%02x"' /tmp/verify_fh.bin)
    imgtype=$(hexdump -s 0x12 -n 1 -e '1/1 "0x%02x"' /tmp/verify_fh.bin)
    imgno=$(hexdump -s 0x13 -n 1 -e '1/1 "0x%02x"' /tmp/verify_fh.bin)

    echo "  imgCpStat: $imgcpstat (expect 0xfe)"
    echo "  imgType:   $imgtype (expect 0x07)"
    echo "  imgNo:     $imgno (expect 0x02)"

    if [ "$imgtype" = "0x07" ] && [ "$imgno" = "0x02" ] && [ "$imgcpstat" = "0xfe" ]; then
        echo "  ✓ FH metadata valid"
    else
        echo "  ⚠️  Unexpected metadata values!"
    fi
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Quick Flash Complete!                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  ✓ Device will boot into NBCN mode"
if $FLASH_FH; then
    echo "  ✓ FH image ready as OAD target"
    echo ""
    echo "To test OAD upgrade:"
    echo "  1. Reset device → boots NBCN"
    echo "  2. Start collector and initiate OAD with FH image"
    echo "  3. After OAD completes, device should automatically:"
    echo "     - Switch to FH mode"
    echo "     - Clear network info"
    echo "     - Reboot into FH image"
else
    echo ""
    echo "NBCN-only mode (no FH for OAD)"
fi
echo ""
echo "Next steps:"
echo "  1. Reset/power cycle the device"
echo "  2. Device boots NBCN"
if $FLASH_FH; then
    echo "  3. Use collector to OAD the FH image"
fi
echo ""
