#!/bin/bash

SCRIPT_ROOT=$(readlink -f $(dirname $0))
SRC_ROOT=$(readlink -f $(dirname $0)/..)
ID=$(id -u)

. $SCRIPT_ROOT/config
[ -e "$SCRIPT_ROOT/config_local" ] && . $SCRIPT_ROOT/config_local

if [ $ID -eq 0 -a -d $CHROOT ]; then
# chroot and run this script again
	if [ ! -d "$LOCAL_HOME/$LINUX_DIR" ]; then
		echo git clone -n $LINUX_REPO $LOCAL_HOME/$LINUX_DIR
		git clone -n $LINUX_REPO $LOCAL_HOME/$LINUX_DIR
		(cd $LOCAL_HOME/$LINUX_DIR;
		echo -e \\\t'fetch = +refs/heads/*:refs/heads/*'\\\n\\\t'fetch = +refs/tags/*:refs/tags/*' >> .git/config;
		git remote add ubuntu $UBUNTU_REPO;
		echo -e \\\t'fetch = +refs/heads/*:refs/heads/*'\\\n\\\t'fetch = +refs/tags/*:refs/tags/*' >> .git/config)
	fi
	(cd $LOCAL_HOME/$LINUX_DIR;
	git fetch --all)
	$SCRIPT_ROOT/chroot_shell.sh prepare
	echo chroot $CHROOT su $NORMALUSER -c "/$(basename $SRC_ROOT)/$(basename $SCRIPT_ROOT)/$(basename $0)"
	chroot $CHROOT su $NORMALUSER -c "/$(basename $SRC_ROOT)/$(basename $SCRIPT_ROOT)/$(basename $0)"
	exit 0
elif [ $ID -eq 0 -o ! -d /$NORMALUSER/ ]; then
	echo Please chroot into \"$CHROOT\" and su to \"$NORMALUSER\".
	exit 1
fi

# real script to run in chroot environment

if [ ! -d "$KERNEL_PATH" ]; then
	echo git clone -no torvalds /${LINUX_DIR}.git $KERNEL_PATH
	git clone -no torvalds /${LINUX_DIR}.git $KERNEL_PATH
	(cd $KERNEL_PATH;
	echo -e \\\t'fetch = +refs/heads/*:refs/heads/*'\\\n\\\t'fetch = +refs/tags/*:refs/tags/*' >> .git/config;
	git remote add origin $GIT_REPO;
	echo -e \\\t'fetch = +refs/heads/*:refs/heads/*'\\\n\\\t'fetch = +refs/tags/*:refs/tags/*' >> .git/config)
fi
cd $KERNEL_PATH
git fetch --all
git clean -fd
git reset --hard
git checkout -b $GIT_BRANCH $GIT_TAG || (git checkout --orphan ORPHAN; git branch -D $GIT_BRANCH; git checkout -fb $GIT_BRANCH $GIT_TAG)

echo
echo Example for how to continue in chroot environment:
echo -e \\t./chroot_shell.sh
echo -e \\tpatch -p1 \< patch_...txt
echo -e \\tsed -i \'/^EXTRAVERSION/s/$/.0-kirkwood/\' Makefile
echo -e \\tgit add -u \# add all updated files to index
echo -e \\tgit \#add -A \# add all new files to index to prevent being ereased by \"git clean -fd\" in script 2
echo -e \\tgit diff --cached
echo -e \\tlogout
echo -e \\t./2_chroot_build.sh

sed -i "/^EXTRAVERSION/s/\$/.0-$FLAVOUR/" Makefile
