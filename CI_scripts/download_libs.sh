mkdir libs && cd libs

curl -O -J http://apt.bingner.com/debs/1443.00/libimobiledevice6_1.3.1-1_iphoneos-arm.deb
curl -O -J http://apt.bingner.com/debs/1443.00/libirecovery3_1.0.1-1_iphoneos-arm.deb
curl -O -J http://apt.bingner.com/debs/1443.00/libusb-1.0-0_1.0.23-1_iphoneos-arm.deb
curl -O -J http://apt.bingner.com/debs/1443.00/libusbmuxd6_2.0.3-1_iphoneos-arm.deb


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

