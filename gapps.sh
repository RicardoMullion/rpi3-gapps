#!/bin/bash

# raspberry pi android tv leanback gapps installtion script

TIMESTAMP="20160816"
PACKAGE="open_gapps-arm-6.0-tvstock-$TIMESTAMP-UNOFFICIAL.zip"

SHOW_HELP=false
ADB_ADDRESS=""

# ------------------------------------------------
# Helping functions
# ------------------------------------------------

show_help()
{
cat << EOF
USAGE:
  $0 [-h] -a IP
OPTIONS:
  -h  Show help
  -a  IP address for ADB
EOF
}

reboot_device()
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
        adb connect $ADB_ADDRESS > /dev/null
        if is_booted; then
            break
        fi
    done
}

prepare_device()
{
    echo " * Checking available devices..."
    ping -c 1 $ADB_ADDRESS > /dev/null 2>&1
    reachable="$?"
    if [ "$reachable" -ne "0" ]; then
        echo "ERR: no device with address $ADB_ADDRESS found"
        echo ""
        show_help
        exit 1
    fi

    echo " * Enabling root access..."
    wait_for_adb
    adb root

    echo " * Remounting system partition..."
    wait_for_adb
    adb remount
}

prepare_gapps()
{
    mkdir -p gapps

    if [ ! -d "gapps/pkg" ]; then
        echo " * Downloading OpenGApps package..."
        echo ""
        wget https://www.dropbox.com/s/cb2l9n5bs5g41fs/open_gapps-arm-6.0-tvstock-$timestamp-UNOFFICIAL.zip -O gapps/$PACKAGE
    fi

    if [ ! -f "gapps/$PACKAGE" ]; then
        echo "ERR: package download failed!"
    fi

    if [ ! -d "gapps/pkg" ]; then
        echo " * Unzipping package..."
        echo ""
        unzip "gapps/$PACKAGE" -d "gapps/pkg"
        echo ""
    fi

    if [ ! -d "gapps/pkg" ]; then
        echo "ERR: unzipping the package failed!"
        exit 1
    fi
}

create_partition()
{
    echo " * Extracting supplied packages..."
    rm -rf gapps/tmp > /dev/null 2>&1
    mkdir -p gapps/tmp
    find . -name "*.tar.xz" -exec tar -xf {} -C gapps/tmp/ \;

    echo " * Creating local system partition..."
    rm -rf gapps/sys > /dev/null 2>&1
    mkdir -p gapps/sys
    for dir in gapps/tmp/*/
    do
      pkg=${dir%*/}
      dpi=$(ls -1 $pkg | head -1)

      echo "  - including $pkg/$dpi"
      rsync -aq $pkg/$dpi/ gapps/sys/
    done

    # no leftovers
    rm -rf gapps/tmp
}

install_package()
{
    echo " * Removing old package installer..."
    adb shell "rm -rf system/priv-app/PackageInstaller"

    echo " * Pushing system files..."
    adb push gapps/sys /system

    echo " * Enforcing a reboot, please be patient..."
    wait_for_adb
    reboot_device

    echo " * Waiting for ADB (errors are OK)..."
    wait_for_adb

    echo " * Applying correct permissions..."
    adb shell "pm grant com.google.android.gms android.permission.ACCESS_COARSE_LOCATION"
    adb shell "pm grant com.google.android.gms android.permission.ACCESS_FINE_LOCATION"
    adb shell "pm grant com.google.android.tungsten.setupwraith android.permission.READ_PHONE_STATE"
}

# ------------------------------------------------
# Script entry point
# ------------------------------------------------

# save the passed options
while getopts ":a:h" flag; do
case $flag in
    "a") ADB_ADDRESS="$OPTARG" ;;
    "h") SHOW_HELP=true ;;
    *)
         echo ""
         echo "ERR: invalid option (-$flag $OPTARG)"
         echo ""
         show_help
         exit 1
esac
done

if [[ "$SHOW_HELP" = true ]]; then
    show_help
    exit 1
fi

echo "GApps installation script for RPi"
echo "Used package: $PACKAGE"
echo "ADB IP address: $ADB_ADDRESS"
echo ""

prepare_device
prepare_gapps
create_partition
install_package

echo " * Waiting for ADB..."
wait_for_adb

echo "All done. The device will reboot once again."
reboot_device
adb kill-server
