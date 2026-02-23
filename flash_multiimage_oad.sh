#!/bin/bash
# Complete multi-image OAD flashing script
# Flashes Factory, NBCN, and FH images with proper metadata
# Configures NBCN as currently running, FH ready to boot

set -e  # Exit on error

export CCS_ROOT=/home/a1244925/ti/ccs1281/ccs
cd /home/a1244925/ti/flash-rover

FACTORY_BIN="/home/a1244925/workspace_ccstheia/sensor_oad_offchip_src_LP_CC1312R7_FACTORY/Release/sensor_oad_offchip_src_LP_CC1312R7_FACTORY.bin"
NBCN_BIN="/home/a1244925/workspace_ccstheia/sensor_oad_offchip_src_LP_CC1312R7_NBCN/Release/sensor_oad_offchip_src_LP_CC1312R7_NBCN.bin"
FH_BIN="/home/a1244925/workspace_ccstheia/sensor_oad_offchip_src_LP_CC1312R7_FH/Release/sensor_oad_offchip_src_LP_CC1312R7_FH.bin"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Multi-Image OAD Flash Programming                  ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  Device:      CC1312R7                                     ║"
echo "║  XDS:         L24001FR                                     ║"
echo "║  Flash Size:  1 MB                                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if binaries exist
echo "Checking binary files..."
for bin_file in "$FACTORY_BIN" "$NBCN_BIN" "$FH_BIN"; do
    if [ ! -f "$bin_file" ]; then
        echo "✗ Error: Binary not found: $bin_file"
        exit 1
    fi
done
echo "✓ All binary files found"
echo ""

# Step 1: Mass erase
echo "═══ Step 1: Mass Erase External Flash ═══"
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR erase 0 1048576
if [ $? -ne 0 ]; then
    echo "✗ Mass erase failed!"
    exit 1
fi
echo "✓ External flash erased"
echo ""

# Step 2: Create metadata
echo "═══ Step 2: Generate Metadata ═══"
python3 /tmp/create_multiimage_metadata.py
if [ $? -ne 0 ]; then
    echo "✗ Metadata creation failed!"
    exit 1
fi
echo ""

# Step 3: Flash Factory image
echo "═══ Step 3: Flash Factory Image ═══"
echo "Writing to 0x04000 (16384)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 16384 -i "$FACTORY_BIN" 2>&1 | tail -3
if [ $? -eq 0 ]; then
    echo "✓ Factory image written"
else
    echo "✗ Factory image write failed"
    exit 1
fi
echo ""

# Step 4: Flash NBCN image
echo "═══ Step 4: Flash NBCN Image ═══"
echo "Writing to 0x36000 (221184)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 221184 -i "$NBCN_BIN" 2>&1 | tail -3
if [ $? -eq 0 ]; then
    echo "✓ NBCN image written"
else
    echo "✗ NBCN image write failed"
    exit 1
fi
echo ""

# Step 5: Flash FH image
echo "═══ Step 5: Flash FH Image ═══"
echo "Writing to 0x68000 (425984)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 425984 -i "$FH_BIN" 2>&1 | tail -3
if [ $? -eq 0 ]; then
    echo "✓ FH image written"
else
    echo "✗ FH image write failed"
    exit 1
fi
echo ""

# Step 6: Flash Factory metadata
echo "═══ Step 6: Flash Factory Metadata ═══"
echo "Writing to Page 0 (0x0000)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 0 -i /tmp/factory_metadata.bin 2>&1 | tail -3
if [ $? -eq 0 ]; then
    echo "✓ Factory metadata written"
else
    echo "✗ Factory metadata write failed"
    exit 1
fi
echo ""

# Step 7: Flash NBCN metadata
echo "═══ Step 7: Flash NBCN Metadata ═══"
echo "Writing to Page 2 (0x2000 = 8192)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 8192 -i /tmp/nbcn_metadata.bin 2>&1 | tail -3
if [ $? -eq 0 ]; then
    echo "✓ NBCN metadata written"
else
    echo "✗ NBCN metadata write failed"
    exit 1
fi
echo ""

# Step 8: Flash FH metadata
echo "═══ Step 8: Flash FH Metadata ═══"
echo "Writing to Page 3 (0x3000 = 12288)..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 12288 -i /tmp/fh_metadata.bin 2>&1 | tail -3
if [ $? -eq 0 ]; then
    echo "✓ FH metadata written"
else
    echo "✗ FH metadata write failed"
    exit 1
fi
echo ""

# Step 9: Write NVS Mode Configuration
echo "═══ Step 9: Write NVS Mode Configuration ═══"
echo "Configuring BIM to boot NBCN by default..."

# Generate NVS config
python3 /tmp/create_nvs_mode_config.py > /dev/null

# Write NBCN mode config (default)
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 631040 -i /tmp/nvs_mode_nbcn.bin 2>&1 | tail -3
if [ $? -eq 0 ]; then
    echo "✓ NVS mode configuration written (default: NBCN)"
else
    echo "✗ NVS mode write failed"
    exit 1
fi
echo ""

# Step 10: Verify flash contents
echo "═══ Step 10: Verify Flash Contents ═══"
bash check_flash.sh

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Flash Programming Complete!                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Flash Layout:"
echo "  Page 0 (0x00000): Factory metadata (imgNo=0x00, imgType=0x05)"
echo "  0x04000-0x35FFF:  Factory image"
echo "  Page 2 (0x02000): NBCN metadata (imgNo=0x01, imgType=0x07, imgCpStat=0xFE)"
echo "  0x36000-0x67FFF:  NBCN image"
echo "  Page 3 (0x03000): FH metadata (imgNo=0x02, imgType=0x07, imgCpStat=0xFE)"
echo "  0x68000-0x99FFF:  FH image"
echo "  0x9A100:          NVS mode config (requestedMode=NBCN)"
echo ""
echo "Configuration:"
echo "  ✓ All images ready to boot (imgCpStat=0xFE)"
echo "  ✓ NVS mode configured for NBCN (default boot mode)"
echo "  ✓ BIM will boot NBCN on first reset"
echo ""
echo "To switch to FH mode:"
echo "  ./write_nvs_mode.sh fh"
echo "  Then reset the device"
echo ""
echo "To revert to NBCN mode:"
echo "  ./write_nvs_mode.sh nbcn"
echo "  Then reset the device"
echo ""
echo "Next steps:"
echo "  1. Reset/power cycle the device → boots NBCN"
echo "  2. To test FH: ./write_nvs_mode.sh fh && reset device"
echo "  3. Device will boot FH from external flash"
echo ""
