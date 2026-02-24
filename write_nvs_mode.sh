#!/bin/bash
# Write NVS Mode Configuration to external flash
# This configures which mode BIM will boot into

set -e

export CCS_ROOT=/home/a1244925/ti/ccs1281/ccs
cd /home/a1244925/ti/flash-rover

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <mode>"
    echo "  mode: fh or nbcn"
    exit 1
fi

MODE=$1

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Writing NVS Mode Configuration                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Generate the NVS config file
echo "Generating NVS mode configuration..."
python3 /tmp/create_nvs_mode_config.py > /dev/null

if [ "$MODE" = "fh" ]; then
    echo "Configuring BIM to boot FH mode..."
    NVS_FILE="/tmp/nvs_mode_fh.bin"
    IMG_NO=2
elif [ "$MODE" = "nbcn" ]; then
    echo "Configuring BIM to boot NBCN mode..."
    NVS_FILE="/tmp/nvs_mode_nbcn.bin"
    IMG_NO=1
else
    echo "✗ Invalid mode: $MODE"
    echo "  Valid modes: fh, nbcn"
    exit 1
fi

# Reset target image imgCpStat to 0xFE (NEED_COPY) so BIM will boot it
echo "Resetting target image metadata to NEED_COPY..."
/tmp/reset_imgcpstat.sh $IMG_NO || echo "  (Warning: imgCpStat reset failed)"
echo ""

# Write to NVS region at 0x9A100 (631040)
echo "Writing NVS config to external flash at 0x9A100..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR write 631040 -i "$NVS_FILE" 2>&1 | tail -3

if [ $? -eq 0 ]; then
    echo "✓ NVS mode configuration written successfully"
else
    echo "✗ NVS write failed"
    exit 1
fi

# Verify the write
echo ""
echo "Verifying NVS config..."
./scripts/cli-entry/flash-rover --device cc1312r7 --xds L24001FR read 631040 33 --output /tmp/nvs_verify.bin 2>/dev/null

echo "Read back from flash:"
hexdump -C /tmp/nvs_verify.bin | head -5

# Parse and display
magic=$(hexdump -s 0 -n 4 -e '1/4 "0x%08X"' /tmp/nvs_verify.bin)
version=$(hexdump -s 4 -n 1 -e '1/1 "%u"' /tmp/nvs_verify.bin)
reqMode=$(hexdump -s 5 -n 1 -e '1/1 "%u"' /tmp/nvs_verify.bin)
lastMode=$(hexdump -s 6 -n 1 -e '1/1 "%u"' /tmp/nvs_verify.bin)
fhCap=$(hexdump -s 11 -n 1 -e '1/1 "%u"' /tmp/nvs_verify.bin)

echo ""
echo "Parsed values:"
echo "  Magic:         $magic (should be 0x45444F4D 'MODE')"
echo "  Version:       $version (should be 1)"
echo "  Requested mode: $reqMode (1=NBCN, 2=FH)"
echo "  Last mode:     $lastMode"
echo "  FH capable:    $fhCap"

echo ""
if [ "$magic" = "0x45444F4D" ]; then
    echo "✓ NVS configuration verified successfully"
    echo ""
    echo "═══════════════════════════════════════════════"
    if [ "$reqMode" = "2" ]; then
        echo "Device configured to boot FH mode"
    elif [ "$reqMode" = "1" ]; then
        echo "Device configured to boot NBCN mode"
    fi
    echo "Reset the device to activate new configuration"
    echo "═══════════════════════════════════════════════"
else
    echo "✗ Verification failed - magic number mismatch"
    exit 1
fi
