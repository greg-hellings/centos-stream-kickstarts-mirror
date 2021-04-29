# This is the common bits between Container base images
#
# To keep this image minimal it only installs English language. You need to change
# dnf configuration in order to enable other languages.
#
# ##  Hacking on this image ###
# This kickstart is processed using Anaconda-in-ImageFactory (via Koji typically),
# but you can run imagefactory locally too.
#
# To do so, testing local changes, first you'll need a TDL file.  I store one here:
# https://pagure.io/fedora-atomic/raw/master/f/fedora-atomic-rawhide.tdl
#
# Then, once you have imagefactory and imagefactory-plugins installed, run:
#
#   ksflatten -c CentOS-Stream-9-container-base[-minimal].ks -o CentOS-Stream-9-container-base-test.ks
#   imagefactory --debug target_image --template /path/to/fedora-atomic-rawhide.tdl --parameter offline_icicle true --file-parameter install_script $(pwd)/CentOS-Stream-9-container-base-test.ks docker
#

text # don't use cmdline -- https://github.com/rhinstaller/anaconda/issues/931
bootloader --disabled
timezone --isUtc --nontp Etc/UTC
rootpw --lock --iscrypted locked
keyboard us
network --bootproto=dhcp --device=link --activate --onboot=on
reboot

# boot partitions are irrelevant as the final container image is a tarball
zerombr
clearpart --all
autopart --noboot --nohome --noswap --nolvm --fstype=ext4

%addon com_redhat_kdump --disable
%end

%packages --excludedocs --instLangs=en --nocore
redhat-release
bash
rootfiles
coreutils-single
glibc-minimal-langpack
crypto-policies-scripts
-kernel
-dosfstools
-e2fsprogs

# s390utils-base needs fuse-libs. Comment it for now.
#-fuse-libs
-gnupg2-smime
-libss # used by e2fsprogs
-pinentry
# gdk-pixbuf2-2.40.0-3.el9.s390x requires shared-mime-info
#-shared-mime-info
-trousers
-xkeyboard-config
-xfsprogs
-qemu-guest-agent

%end

%post --erroronfail --log=/root/anaconda-post.log
set -eux

# Support for subscription-manager secrets
ln -s /run/secrets/etc-pki-entitlement /etc/pki/entitlement-host
ln -s /run/secrets/rhsm /etc/rhsm-host

#https://bugzilla.redhat.com/show_bug.cgi?id=1201663
rm -f /etc/systemd/system/multi-user.target.wants/rhsmcertd.service

#fips mode
# secrets patch creates /run/secrets/system-fips if /etc/system-fips exists on the host
#in turn, openssl in the container checks /etc/system-fips but dangling symlink counts as nonexistent
ln -s /run/secrets/system-fips /etc/system-fips

# Set install langs macro so that new rpms that get installed will
# only install langs that we limit it to.
LANG="C.utf8"
echo "%_install_langs $LANG" > /etc/rpm/macros.image-language-conf
echo "LANG=C.utf8" > /etc/locale.conf

# https://bugzilla.redhat.com/show_bug.cgi?id=1400682
# https://bugzilla.redhat.com/show_bug.cgi?id=1672230
## CS TODO - Import GPG keys when we have them
#echo "Import RPM GPG key"
#rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-centos-stream-release

#echo "# fstab intentionally empty for containers" > /etc/fstab
#this is not possible, guestmount needs fstab => brew build crashes without it
#fstab is removed in TDL when tar-ing files

# Remove network configuration files leftover from anaconda installation
# https://bugzilla.redhat.com/show_bug.cgi?id=1713089
rm -f /etc/sysconfig/network-scripts/ifcfg-*

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

%end
