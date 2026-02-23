#!/bin/bash
# Quick script to check external flash metadata

export CCS_ROOT=/home/a1244925/ti/ccs1281/ccs
FLASH_ROVER=/home/a1244925/ti/flash-rover/scripts/cli-entry/flash-rover

echo "=== Reading External Flash Metadata ==="
echo ""

# Read all metadata pages
# Page 0: Factory (0x0000)
# Page 2: NBCN (0x2000 = 8192)
# Page 3: FH (0x3000 = 12288)
$FLASH_ROVER --device cc1312r7 --xds L24001FR read 0 256 --output /tmp/page0_meta.bin 2>/dev/null
$FLASH_ROVER --device cc1312r7 --xds L24001FR read 8192 256 --output /tmp/page2_meta.bin 2>/dev/null
$FLASH_ROVER --device cc1312r7 --xds L24001FR read 12288 256 --output /tmp/page3_meta.bin 2>/dev/null

# Metadata offsets in imgFixedHdr_t:
# imgCpStat: 0x10 (16)
# crcStat:   0x11 (17)
# imgType:   0x12 (18)
# imgNo:     0x13 (19)

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              FACTORY IMAGE (Page 0)                        ║"
echo "╠════════════════════════════════════════════════════════════╣"

# Check if empty
if hexdump -C /tmp/page0_meta.bin -n 16 | grep -q "ff ff ff ff ff ff ff ff"; then
    echo "║ Status: ❌ EMPTY (no image)                                ║"
else
    imgcpstat=$(hexdump -s 0x10 -n 1 -e '1/1 "0x%02x"' /tmp/page0_meta.bin)
    crcstat=$(hexdump -s 0x11 -n 1 -e '1/1 "0x%02x"' /tmp/page0_meta.bin)
    imgtype=$(hexdump -s 0x12 -n 1 -e '1/1 "0x%02x"' /tmp/page0_meta.bin)
    imgno=$(hexdump -s 0x13 -n 1 -e '1/1 "0x%02x"' /tmp/page0_meta.bin)
    echo "║ imgCpStat: $imgcpstat (0xFE=NEED_COPY, 0xFC=COPY_DONE)         ║"
    echo "║ crcStat:   $crcstat (0xFE/0xFF=valid)                         ║"
    echo "║ imgType:   $imgtype (expect 0x05 FACTORY)                     ║"
    echo "║ imgNo:     $imgno (expect 0x00)                              ║"

    if [ "$imgtype" = "0x05" ] && [ "$imgno" = "0x00" ]; then
        echo "║ ✓ Factory metadata valid                                  ║"
    else
        echo "║ ⚠️  Unexpected values!                                     ║"
    fi
fi
echo "╚════════════════════════════════════════════════════════════╝"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              NBCN IMAGE (Page 2)                           ║"
echo "╠════════════════════════════════════════════════════════════╣"

if hexdump -C /tmp/page2_meta.bin -n 16 | grep -q "ff ff ff ff ff ff ff ff"; then
    echo "║ Status: ❌ EMPTY (no image)                                ║"
else
    imgcpstat=$(hexdump -s 0x10 -n 1 -e '1/1 "0x%02x"' /tmp/page2_meta.bin)
    crcstat=$(hexdump -s 0x11 -n 1 -e '1/1 "0x%02x"' /tmp/page2_meta.bin)
    imgtype=$(hexdump -s 0x12 -n 1 -e '1/1 "0x%02x"' /tmp/page2_meta.bin)
    imgno=$(hexdump -s 0x13 -n 1 -e '1/1 "0x%02x"' /tmp/page2_meta.bin)
    echo "║ imgCpStat: $imgcpstat (0xFE=NEED_COPY, 0xFC=COPY_DONE)         ║"
    echo "║ crcStat:   $crcstat (0xFE/0xFF=valid)                         ║"
    echo "║ imgType:   $imgtype (expect 0x07 APPSTACKLIB)                 ║"
    echo "║ imgNo:     $imgno (expect 0x01)                              ║"

    if [ "$imgtype" = "0x07" ] && [ "$imgno" = "0x01" ]; then
        echo "║ ✓ NBCN metadata valid                                     ║"
    else
        echo "║ ⚠️  Unexpected values!                                     ║"
        if [ "$imgno" = "0xff" ]; then
            echo "║ ⚠️  imgNo = 0xFF - imgBinUtil.py fix NOT applied!         ║"
        fi
    fi
fi
echo "╚════════════════════════════════════════════════════════════╝"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              FH IMAGE (Page 3)                             ║"
echo "╠════════════════════════════════════════════════════════════╣"

if hexdump -C /tmp/page3_meta.bin -n 16 | grep -q "ff ff ff ff ff ff ff ff"; then
    echo "║ Status: ❌ EMPTY (no image)                                ║"
else
    imgcpstat=$(hexdump -s 0x10 -n 1 -e '1/1 "0x%02x"' /tmp/page3_meta.bin)
    crcstat=$(hexdump -s 0x11 -n 1 -e '1/1 "0x%02x"' /tmp/page3_meta.bin)
    imgtype=$(hexdump -s 0x12 -n 1 -e '1/1 "0x%02x"' /tmp/page3_meta.bin)
    imgno=$(hexdump -s 0x13 -n 1 -e '1/1 "0x%02x"' /tmp/page3_meta.bin)
    echo "║ imgCpStat: $imgcpstat (0xFE=NEED_COPY, 0xFC=COPY_DONE)         ║"
    echo "║ crcStat:   $crcstat (0xFE/0xFF=valid)                         ║"
    echo "║ imgType:   $imgtype (expect 0x07 APPSTACKLIB)                 ║"
    echo "║ imgNo:     $imgno (expect 0x02)                              ║"

    if [ "$imgtype" = "0x07" ] && [ "$imgno" = "0x02" ]; then
        echo "║ ✓ FH metadata valid                                       ║"
    else
        echo "║ ⚠️  Unexpected values!                                     ║"
        if [ "$imgno" = "0xff" ]; then
            echo "║ ⚠️  imgNo = 0xFF - imgBinUtil.py fix NOT applied!         ║"
        fi
    fi
fi
echo "╚════════════════════════════════════════════════════════════╝"

echo ""
echo "Flash Layout:"
echo "  Page 0 (0x00000): Factory metadata (imgNo=0x00, imgType=0x05)"
echo "  Page 1 (0x01000): [Empty - skipped by OAD due to EFL_NUM_FACT_IMAGES]"
echo "  Page 2 (0x02000): NBCN metadata (imgNo=0x01, imgType=0x07)"
echo "  Page 3 (0x03000): FH metadata (imgNo=0x02, imgType=0x07)"
