#!/bin/bash
filename=$1
if stringContains "/" $filename; then
  # you gave us some kind of path
  bn=$(basename $filename)
  spath=$(directory $filename)
else
  # assume no path
  bn=$filename
  spath=$(pwd)
fi
cp $filename /tmp/
cd /tmp/
base=$(echo $bn|cut -d"." -f1)
newbase=$base-mt-$(date +"%Y%m%d")
mkdir -p $newbase
dpkg-deb -R $bn $newbase
cd $newbase
vim DEBIAN/control
find . -type f -not -path "./DEBIAN/*" -exec md5sum {} + | sort -k 2 | sed 's/\.\/\(.*\)/\1/' > DEBIAN/md5sums
cd ..
dpkg-deb -b $newbase $newbase.deb
cp $newbase.deb $spath
cd $spath
