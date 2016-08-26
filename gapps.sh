#!/bin/bash

# raspberry pi android tv leanback gapps installtion script

timestamp="20160816"
package="open_gapps-arm-6.0-tvstock-$timestamp-UNOFFICIAL.zip"
address="192.168.0.101"

# ------------------------------------------------
# Helping functions
# ------------------------------------------------

reboot_now()
{
  adb reboot bootloader > /dev/null &
  sleep 10
}

is_booted()
{
  [[ "$(adb shell getprop sys.boot_completed | tr -d '\r')" == 1 ]]
}

wait_for_adb()
{
  while true; do
    sleep 1
    adb kill-server > /dev/null
    adb connect $address > /dev/null
    if is_booted; then
      break
    fi
  done
}

# ------------------------------------------------
# Script entry point
# ------------------------------------------------

echo "GApps installation script for RPi"
echo "Used package: $package"
echo "Device address: $address"

if [ ! -d "org" ]; then
  echo " * Downloading OpenGApps package..."
  wget https://www.dropbox.com/s/cb2l9n5bs5g41fs/open_gapps-arm-6.0-tvstock-$timestamp-UNOFFICIAL.zip
  unzip $package -d org
fi

if [ ! -d "org" ]; then
  echo "ERR: unzipping the package failed!"
  exit 1
fi

echo " * Extracting supplied packages..."
rm -rf tmp > /dev/null 2>&1
mkdir -p tmp
find . -name "*.tar.xz" -exec tar -xf {} -C tmp/ \;

echo " * Removing conflicting packages..."
echo "  - PackageInstaller (Google)"
rm -rf tmp/packageinstallergoogle* > /dev/null 2>&1
rm -rf tmp/tvpackageinstallergoogle* > /dev/null 2>&1

echo " * Creating system partition..."
rm -rf sys > /dev/null 2>&1
mkdir -p sys
for dir in tmp/*/
do
  pkg=${dir%*/}
  dpi=$(ls -1 $pkg | head -1)

  echo "  - including $pkg/$dpi"
  rsync -aq $pkg/$dpi/ sys/
done

echo " * Enabling root access..."
wait_for_adb
adb root

echo " * Remounting system partition..."
wait_for_adb
adb remount

echo " * Pushing system files..."
adb push sys /system

echo " * Enforcing a reboot, please be patient..."
wait_for_adb
reboot_now

echo " * Waiting for ADB (errors are OK)..."
wait_for_adb

echo " * Applying correct permissions..."
adb shell "pm grant com.google.android.gms android.permission.ACCESS_COARSE_LOCATION"
adb shell "pm grant com.google.android.gms android.permission.ACCESS_FINE_LOCATION"
adb shell "pm grant com.google.android.tungsten.setupwraith android.permission.READ_PHONE_STATE"

echo " * Waiting for ADB..."
wait_for_adb

echo "All done. The device will reboot once again."
reboot_now
adb kill-server
