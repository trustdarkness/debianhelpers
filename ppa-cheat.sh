#!/bin/bash
#make sure you have confirm_yes from .bashrc
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  onlykeys=0
  userkeys=""
  case $1 in
    -k|--keys_only)
      onlykeys=1
      shift # past argument
      shift # past value
      ;;
    -K|--keyfile)
      userkey="$2"
      shift
      shift
      ;;
    -h|--help)
      echo "A hacky replacement for apt-add-repository intended for debian"
      echo "based systems that would like to install via ppa.  This bypasses"
      echo "all kinds of sanity checking and future proofing in the"
      echo "original.  Use at your own risk. Provided as is with no"
      echo "guarantees, warranty, or even support (unless you're lucky" 
      echo "enough to catch me when you have a problem)."
      echo " " 
      echo "-K --keyfile"
      echo "   provide your own keyfile in case GPG is being unhappy"
      echo "   trying to download keys."
      echo "-k --keys_only 
      echo     only do the key steps, assuming sources.list is already"
      echo "   written and where we expect it to be."
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
    POSITIONAL_ARGS+=("$1") # save positional arg
    shift # past argument
    ;;
  esac
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

source $HOME/.bashrc
LFTP=$(which lftp)
if [ -z "$LFTP" ]; then
  echo "Please install lftp"
  exit 1
fi
ELINKS=$(which elinks)
if [ -z "$ELINKS" ]; then
  echo "Please install lftp"
  exit 1
fi
arch="$(dpkg --print-architecture)"
ppa=$(echo $1|cut -d":" -f2)
teamname=$(echo $ppa|cut -d"/" -f1)
ppaname=$(echo $ppa|cut -d"/" -f2)
keydest=/usr/share/keyrings/$teamname.gpg
function get_keys() {
  userurl=https://launchpad.net/~$teamname
  fingerprint="$($ELINKS --no-references --no-numbering --dump $userurl|grep -A1 OpenPGP|tail -n1)"
  if [ -z "${GNUPGHOME}" ]; then
    GNUPGHOME=$HOME/.gnupg
  fi
  echo "keyserver hkps://keyserver.ubuntu.com" >> "${GNUPGHOME}/dirmngr.conf"
  gpgconf --kill dirmngr
  echo $fingerprint
  gpg -a -o $teamname.gpg --recv-keys $fingerprint 
  if [ -f "$teamname.gpg" ]; then
    sudo mv $teamname.gpg $dest
    return "[arch=$arch signed-by=$keydest]"
  else
    return ""
  fi
}
function update_existing() {
  cdist="$1"
  keysection="$2"
  if [ -z "$cdist" ]; then 
    >&2 printf "get_existing needs cdist.  exiting."
    return 1
  fi
  if [ -z "$cdist" ]; then 
    >&2 printf "get_existing needs cdist.  exiting."
    return 1
  fi
  filename=$teamname-ubuntu-ppa-$cdist.list
  listfile=$(cat $filename |grep deb)
  afterdeb=$(echo $listfile| cut -d" " -f2+)
  debline="deb $keysection $afterdeb"
  echo "Updating $filename to:"
  echo ""
  echo "$debline"
  confirm_yes "OK?"
  sudo mv $filename /tmp/
  fullpath="/etc/apt/sources.list.d/$filename"
  echo "$debline" | sudo tee -a $fullpath 
  exit 0
}
if [ $onlykeys -eq 1 ]; then 
  keysection=get_keys
  if [ -n "$keysection" ]; then 
    echo "Success getting keys."
    # read in file here and add keysection
  else
    echo "Still couldn't get keys.  Try again or troubleshoot GPG."
    exit 1
  fi
fi
PPA=$(echo $1|cut -d":" -f2)
teamname=$(echo $PPA|cut -d"/" -f1)
ppaname=$(echo $PPA|cut -d"/" -f2)
url=http://ppa.launchpadcontent.net/$teamname/$ppaname/ubuntu
echo "Getting PPA details from $url"
dists=$(LS_COLORS=no $LFTP -e 'cls -1; exit' "$url/dists" 2)
num=$(echo dists|wc -l)
if [ $num -eq 1 ]; then
  cdist=${dists%?}
else
  echo "Found these dists, please choose one by entering the number:"
  avail=()
  ctr=0
  for dist in $dists; do
    dist=${dist%?}
    echo "$ctr : $dist"
    avail+=( $dist )
    ((ctr=ctr+1))
  done
  echo "Which dist should we use?"
  read choice
  cdist=${avail[$choice]}
fi
pools=$(LS_COLORS=no $LFTP -e 'cls -1; exit' "$url/pool" 2)
if [ $(echo pools|wc -l) -eq 1 ]; then
  poolstring=${pools%?}
else
  poolstring=""
  for pool in $pools; do 
    poolstring+=${pool%?}" "
  done
fi
if [ -n "$userkey" ]; then
  echo "using user supplied key at $userkey"
  if stringContains ".asc" $userkey; then
    gpg --dearmor $userkey
    userkey=$userkey.gpg
  fi 
  sudo mv $userkey $keydest
  keysection="[arch=$arch signed-by=$keydest]"
else
  # now we get the key
  keysection="get_key()"
fi
if [ -z "$keysection" ]; then
    echo "failed to write usable key materia;, GPG is finicky.  You can:"
    echo "1. Ctrl-c to cancel and try the whole procedure later."
    echo "2. Let me write the sources file now, then you can run with -k"
    echo "   to _only_ try adding key material later."
    echo "3. Download the key by hand and re-run with -K \$loc_of_key"
    echo ""
    echo "If you're going with options 2 or 3, you should let me write the"
    echo "sources file now."
    confirm_yes "Write the sources file now and add the key to it later?"
    debline="deb $url $cdist $poolstring"
else
  debline="deb $keysection $url $cdist $poolstring"
fi
filename=$teamname-ubuntu-ppa-$cdist.list
fullpath="/etc/apt/sources.list.d/$filename"
echo "writing the following:"
echo "$debline" 
echo "to $fullpath. "
confirm_yes "OK?"
echo "$debline" | sudo tee -a $fullpath
