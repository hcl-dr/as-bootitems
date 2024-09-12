#!/usr/bin/env bash

#
# Build a RAUC bundle from ext4 image file
# Optionally sign FIT image in boot folder
fitkeydir="$PWD"
rauckey=$RAUC_KEY_FILE
rauccert=$RAUC_CERT_FILE
pkcs11_flag=false
mkimage_flags=
rauc_file=
rauc_xtra=
pkeyout=
algo=rsa4096

panic () {
    echo "$1"
    exit 1
}

cleanup_fit () {
    echo "Unmount $2"
    sudo umount "$2"
    echo "Run fsck"
    e2fsck -p -f "$1"
    sudo rmdir "$2"
}

compatible=dr-imx8mp
version=unknown
fitflag=false

if ! options=$(getopt -l compatible,version,signfit,fitkey,fitkeydir,rauckey,rauccert,pkcs11,raucfile,raucimcert,pkeyout,algo: -- "$@")
then
    exit 1
fi

while [ $# -gt 1 ]
do
    # Consume next (1st) argument
    case $1 in
    --compatible) 
        compatible="$2" ; shift ;;
    --version) 
        version="$2" ; shift ;;
    --signfit)
        fitflag=true ;;
    --fitkey)
        fitkey="$2" ; shift ;;
    --fitkeydir)
        fitkeydir="$2" ; shift ;;
    --rauckey)
        rauckey="$2" ; shift ;;
    --rauccert)
        rauccert="$2" ; shift ;;
    --pkcs11)
        export PKCS11_MODULE_PATH="$2"; pkcs11_flag=true ; mkimage_flags="-N pkcs11" ; shift ;;
    --raucfile)
        rauc_file="$2" ; shift ;;
    --raucimcert)
        rauc_xtra="--intermediate=$2" ; shift ;;
    --pkeyout)
        pkeyout="$2" ; shift ;;
    --algo)
        algo="$2" ; shift ;;
    (-*) 
      echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    esac
    # Fetch next argument as 1st
    shift
done

SCRIPT=$(readlink -f $BASH_SOURCE)
top=$(readlink -f $(dirname $SCRIPT))

file=$1
if $pkcs11_flag; then
    fitkeydir="object=$fitkey"
fi

[ -z "$file" ] && panic "Need ext4 as input"

[ -n "$pkeyout" ] && mkimage_flags="$mkimage_flags -K $pkeyout"
rauc_dir=$(mktemp -d)
echo "copy $file to $rauc_dir"
cp "$file" "$rauc_dir"
IMAGE="$rauc_dir"/$(basename "$file")
e2fsck -p -f "$IMAGE"
if [ "$fitflag" == true ]; then
    mntdir=$(mktemp -d)
    echo "Mount $IMAGE on $mntdir"
    sudo mount "$IMAGE" "$mntdir"
    export IMAGE_DIR="$mntdir/boot"
    sed -e "s:@IMAGE_DIR@:$IMAGE_DIR:g" -e "s:@KEY@:$fitkey:g" -e "s:@ALGO@:$algo:g" < "$top/fit.its.in" > "$rauc_dir/fit.its"
    echo "Signing FIT (fakeroot) using $fitkey ..."
    sudo rm -f "$IMAGE_DIR"/fitImage*
    [ "$pkcs11_flag" == true ] && echo "Using PKCS11 module $PKCS11_MODULE_PATH"
    mkarg="$mkimage_flags  -k $fitkeydir -f $rauc_dir/fit.its -r $IMAGE_DIR/fitImage"
    echo "mkimage $mkarg"
    if ! sudo -E mkimage $mkarg; then
        cleanup_fit "$IMAGE" "$mntdir"
        panic "FIT failed"
    fi
    echo "Signed FIT"
    cleanup_fit "$IMAGE" "$mntdir"
fi

bn=$(basename "$file")
bnx="${bn%.*}"
echo "Generate RAUC manifest"
cat << EOF >> "$rauc_dir/manifest.raucm"
[update]
compatible=$compatible
version=$version
build=$(date -u +%F:%H:%M) UTC
description=$bnx

[bundle]
format=plain

[image.rootfs]
filename=$bn
EOF

cat  "$rauc_dir/manifest.raucm"

echo "Signing RAUC image"

[ -z "$rauc_file" ] && rauc_file="$bnx.raucb"
[ -e "$rauc_file" ] && rm -f "$rauc_file"
rauc bundle --cert="$rauccert" --key="$rauckey" $rauc_xtra "$rauc_dir" "$rauc_file"
echo "Remove RAUC workdir $rauc_dir"
rm -rf "$rauc_dir"
