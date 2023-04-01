mkdir libs && cd libs

curl -LO -J http://apt.bingner.com/debs/1443.00/libimobiledevice6_1.3.1-1_iphoneos-arm.deb
curl -LO -J http://apt.bingner.com/debs/1443.00/libirecovery3_1.0.1-1_iphoneos-arm.deb
curl -LO -J http://apt.bingner.com/debs/1443.00/libusb-1.0-0_1.0.23-1_iphoneos-arm.deb
curl -LO -J http://apt.bingner.com/debs/1443.00/libusbmuxd6_2.0.3-1_iphoneos-arm.deb
curl -LO -J https://nightly.link/rA9stuff/gaster/workflows/main/main/gaster.a.zip
curl -LO -J https://nightly.link/rA9stuff/ipwnder_lite/workflows/main/main/checkm8_arm64.a.zip
curl -LO -J https://nightly.link/rA9stuff/ipwnder_lite/workflows/main/main/common.a.zip
curl -LO -J https://nightly.link/rA9stuff/ipwnder_lite/workflows/main/main/iousb.a.zip
curl -LO -J https://nightly.link/rA9stuff/ipwnder_lite/workflows/main/main/ipwnder_main.a.zip
curl -LO -J https://nightly.link/rA9stuff/ipwnder_lite/workflows/main/main/limera1n.a.zip
curl -LO -J https://nightly.link/rA9stuff/ipwnder_lite/workflows/main/main/payload.a.zip
curl -LO -J https://nightly.link/rA9stuff/ipwnder_lite/workflows/main/main/s5l8950x.a.zip


for file in *.zip
do
    unzip "$file"
    rm -f $file
done

for file in *.deb; do
  if [[ -f "$file" ]]; then
    ar -x "$file"
    rm -rf control.tar.gz
    rm -rf debian-binary
    tar --lzma -xvf data.tar.lzma
    mv usr/lib/* .
  fi
done

rm -rf data.tar.lzma usr *.deb

cd ..
curl -O -J https://assets.checkra.in/loader/ios/core/3bda4c4ddb50d7c89eec6260f42f7ba91535de64/strap.tar.lzma
mkdir strap && cd strap
tar --lzma -xvf ../strap.tar.lzma
mv usr/lib/libcrypto.1.1.dylib ../libs
cd ..
rm -rf strap strap.tar.lzma

