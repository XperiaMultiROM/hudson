#!/bin/bash

export KBUILD_BUILD_HOST="XperiaMultiROM"

# Colorize Scripts
red=$(tput setaf 1) # red
grn=$(tput setaf 2) # green
cya=$(tput setaf 6) # cyan
pnk=$(tput bold ; tput setaf 5) # pink
yel=$(tput bold ; tput setaf 3) # yellow
pur=$(tput setaf 5) # purple
txtbld=$(tput bold) # Bold
bldred=${txtbld}$(tput setaf 1) # red
bldgrn=${txtbld}$(tput setaf 2) # green
bldyel=${txtbld}$(tput bold ; tput setaf 3) # yellow
bldblu=${txtbld}$(tput setaf 4) # blue
bldpur=${txtbld}$(tput setaf 5) # purple
bldpnk=${txtbld}$(tput bold ; tput setaf 5) # pink
bldcya=${txtbld}$(tput setaf 6) # cyan
txtrst=$(tput sgr0) # Reset

export USE_CCACHE=1
export CCACHE_NLEVELS=4
export CCACHE_DIR=/var/lib/jenkins/workspace/multirom-yuga/.ccache
ccache -M 60G

rm -rf .repo/local_manifests/*.xml
echo "${bldred}Fetching local manifests...${txtrst}"
curl --create-dirs -L -o .repo/local_manifests/fusion3.xml -O -L https://raw.githubusercontent.com/XperiaMultiROM/local_manifests/master/sony.xml
curl --create-dirs -L -o .repo/local_manifests/vendorblobs.xml -O -L https://raw.githubusercontent.com/XperiaMultiROM/local_manifests/master/blobs.xml
curl --create-dirs -L -o .repo/local_manifests/multirom.xml -O -L https://raw.githubusercontent.com/XperiaMultiROM/local_manifests/master/multirom.xml

echo "${bldcya}Syncing...${txtrst}"
repo sync -c -d -f -j8

echo "${bldcya}Cleaning up...${txtrst}"
make -j8 clobber
rm -rf out/target
. build/envsetup.sh
# Add your device's codename to enable it here - make sure to add it to the local manifests first!
for PRODUCT in yuga odin; do
lunch omni_$PRODUCT-userdebug
echo "${bldgrn}Starting build...${txtrst}"
time make -j5 bootimage;make -j5 recoveryimage;time make -j5 multirom_zip;time make -j5 multirom_uninstaller

echo "${bldyel}Uploading MultiROM files...${txtrst}"
rm -rf /var/www/html/olivier/$PRODUCT/multirom/*
cp out/target/product/$PRODUCT/multirom*zip /var/www/html/olivier/$PRODUCT/multirom
cd out/target/product/$PRODUCT

echo "${bldcya}Starting with kernel_zip...${txtrst}"
mkdir -p kernel_zip/system/lib/modules
mkdir -p kernel_zip/META-INF/com/google/android
echo "${bldcya}Copying boot.img...${txtrst}"
cp boot.img kernel_zip/
echo "${bldcya}Copying kernel modules...${txtrst}"
cp -R system/lib/modules/* kernel_zip/system/lib/modules
echo "${bldcya}Fetching update-binary...${txtrst}"
cd kernel_zip/META-INF/com/google/android
wget http://team-simplicit.com/update-binary
echo "${bldcya}Fetching updater-script...${txtrst}"
wget http://team-simplicit.com/updater-script
croot;cd out/target/product/$PRODUCT
cd kernel_zip
zip -qr ../kernel-omni-mrom-$(date +%Y%m%d)-$PRODUCT.zip ./
croot

echo "${bldcya}Uploading kernel...${txtrst}"
cp out/target/product/$PRODUCT/kernel-omni-mrom*zip /var/www/html/olivier/$PRODUCT/multirom

IMG=out/target/product/$PRODUCT/recovery.img
BASE=/var/www/html/olivier/$PRODUCT/multirom/

RECOVERY_SUBVER="00"
DEST_NAME="TWRP_multirom_$PRODUCT_$(date +%Y%m%d)-$RECOVERY_SUBVER.img"

bbootimg -u $IMG -c "name = mrom$(date +%Y%m%d)-$RECOVERY_SUBVER"
cp $IMG $BASE$DEST_NAME

# We don't want unsigned or duplicated multirom files.
rm -rf /var/www/html/olivier/$PRODUCT/multirom/*unsigned*
rm -rf /var/www/html/olivier/$PRODUCT/multirom/multirom.zip
done
