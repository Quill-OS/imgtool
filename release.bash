#!/bin/bash -xe 

root_command() {
	if [ "${STRICT_ROOT_PERMISSION}" == 1 ]; then
		COMMAND="${@}"
		printf "Warning! This script will execute the following command *as root* if you enter a valid password:\n'%s'\nHit CTRL-C to abort.\n" "${COMMAND}"
		sudo -k
		sudo "${@}" || exit 1
	else
		sudo "${@}" || exit 1
	fi
}

# Variables
if [ -z "${1}" ]; then
	printf "You must provide the 'device' argument."
	exit 1
elif [ -z "${2}" ]; then
	printf "You must provide the 'private key path' argument.\n"
	exit 1
elif [ -z "${3}" ]; then
	printf "You must provide the 'public key path' argument.\n"
	exit 1
elif [ -z "${4}" ]; then
	printf "You must provide the 'kernel type' argument.\nAvailable options are: std, root"
	exit 1
fi

PKEY="${2}"
PUBLICKEY="${3}"
KERNEL_TYPE="${4}"
GIT_BASE_URL="https://github.com/Kobo-InkBox"
PKGS_BASE_URL="http://23.163.0.39"
MOUNT_BASEPATH="/tmp/inkbox-$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 10)"

# Setting current directory to this Git repository
cd "$(dirname '${0}')"
GITDIR="${PWD}"
mkdir -p out/release

build_base_sd_image() {
	printf "==== Building base SD image ====\n"
	IMAGE_FILE="release/inkbox-${DEVICE}.img"
	pushd out/
	# Load NBD module
	# root_command modprobe nbd
	# Manually, on the host :)

	# Create image file (3.6 GiB)
	qemu-img create -f qcow2 "${IMAGE_FILE}" 3865470976
	root_command qemu-nbd --connect /dev/nbd0 "${IMAGE_FILE}"
	# Partition image and write unpartitioned space
	root_command dd if="${GITDIR}/sd/${DEVICE}.bin" of=/dev/nbd0 && sync
	# Format partitions
	root_command mkfs.ext4 /dev/nbd0p1
	root_command mkfs.ext4 /dev/nbd0p2
	root_command mkfs.ext4 /dev/nbd0p3
	root_command mkfs.ext4 /dev/nbd0p4
	# Label partitions
	root_command e2label /dev/nbd0p1 "boot"
	root_command e2label /dev/nbd0p2 "recoveryfs"
	root_command e2label /dev/nbd0p3 "rootfs"
	root_command e2label /dev/nbd0p4 "user"
	popd
}

setup_kernel_repository() {
	if [ -z "${KERNELDIR}" ]; then
		pushd out/
		[ ! -d "kernel" ] && git clone "${GIT_BASE_URL}/kernel"
		pushd kernel/
	else
		pushd "${KERNELDIR}"
	fi
}

setup_u_boot() {
	printf "==== Setting up U-Boot bootloader ====\n"
	setup_kernel_repository

	if [ "${DEVICE}" == "n705" ] || [ "${DEVICE}" == "n905b" ] || [ "${DEVICE}" == "n905c" ] || [ "${DEVICE}" == "n613" ]; then
		env TOOLCHAINDIR="${PWD}/toolchain/gcc-4.8" THREADS=$(($(nproc)*2)) TARGET=arm-linux-gnueabihf scripts/build_u-boot.sh "${DEVICE}"
	elif [ "${DEVICE}" == "n236" ] || [ "${DEVICE}" == "n437" ] || [ "${DEVICE}" == "n306" ] || [ "${DEVICE}" == "n306c" ]; then
		env TOOLCHAINDIR="${PWD}/toolchain/arm-nickel-linux-gnueabihf" THREADS=$(($(nproc)*2)) TARGET=arm-nickel-linux-gnueabihf scripts/build_u-boot.sh "${DEVICE}"
	elif [ "${DEVICE}" == "n249" ]; then
		env TOOLCHAINDIR="${PWD}/toolchain/arm-kobo-linux-gnueabihf" THREADS=$(($(nproc)*2)) TARGET=arm-kobo-linux-gnueabihf scripts/build_u-boot.sh "${DEVICE}"
	fi

	if [ "${DEVICE}" != "n306" ] && [ "${DEVICE}" != "n306c" ] && [ "${DEVICE}" != "n249" ]; then
		cp -v "bootloader/out/u-boot_inkbox.${DEVICE}.bin" "${GITDIR}/out/release/u-boot_inkbox.bin"
		sync
		root_command dd if="${GITDIR}/out/release/u-boot_inkbox.bin" of=/dev/nbd0 bs=1K seek=1 skip=1
		sync
	else
		cp -v "bootloader/out/u-boot_inkbox.${DEVICE}.imx" "${GITDIR}/out/release/u-boot_inkbox.bin"
		sync
		root_command dd if="${GITDIR}/out/release/u-boot_inkbox.bin" of=/dev/nbd0 bs=1K seek=1
		sync
	fi

	popd
}

mount_fs() {
	printf "==== Mounting filesystems ====\n"
	mkdir -p "${MOUNT_BASEPATH}/boot"
	mkdir -p "${MOUNT_BASEPATH}/recoveryfs"
	mkdir -p "${MOUNT_BASEPATH}/rootfs"
	mkdir -p "${MOUNT_BASEPATH}/user"
	root_command mount /dev/nbd0p1 "${MOUNT_BASEPATH}/boot"
	root_command mount /dev/nbd0p2 "${MOUNT_BASEPATH}/recoveryfs"
	root_command mount /dev/nbd0p3 "${MOUNT_BASEPATH}/rootfs"
	root_command mount /dev/nbd0p4 "${MOUNT_BASEPATH}/user"
}

setup_kernel() {
	printf "==== Setting up InkBox OS kernel ====\n"
	setup_kernel_repository

	if [ "${DEVICE}" == "n306" ] || [ "${DEVICE}" == "n306c" ] || [ "${DEVICE}" == "n249" ]; then
		KERNEL_FILE="zImage-${KERNEL_TYPE}"
		if [ "${DEVICE}" == "n249" ]; then
			DTB_FILE="DTB"
			BOOTSCRIPT_FILE="boot.scr"
		fi
	else
		KERNEL_FILE="uImage-${KERNEL_TYPE}"
	fi

	# Replace the public key in kernel
	cd initrd/"${DEVICE}"/opt/
	unsquashfs -d key key.sqsh
	rm -f key.sqsh
	cd key/
	rm -f public.pem
	cp "${PUBLICKEY}" ./public.pem
	mksquashfs . ../key.sqsh -b 1048576 -comp gzip -always-use-fragments
	cd ../
	rm -rf key/
	cd ../../../

	if [ "${DEVICE}" == "n705" ] || [ "${DEVICE}" == "n905b" ] || [ "${DEVICE}" == "n905c" ] || [ "${DEVICE}" == "n613" ]; then
		env GITDIR="${PWD}" TOOLCHAINDIR="${PWD}/toolchain/gcc-4.8" THREADS=$(($(nproc)*2)) TARGET=arm-linux-gnueabihf scripts/build_kernel.sh "${DEVICE}" std
		env GITDIR="${PWD}" TOOLCHAINDIR="${PWD}/toolchain/gcc-4.8" THREADS=$(($(nproc)*2)) TARGET=arm-linux-gnueabihf scripts/build_kernel.sh "${DEVICE}" root

		# Basic Diagnostics Kernel
		if [ "${DEVICE}" == "n905b" ] || [ "${DEVICE}" == "n905c" ] || [ "${DEVICE}" == "n613" ]; then
			env GITDIR="${PWD}" TOOLCHAINDIR="${PWD}/toolchain/gcc-4.8" THREADS=$(($(nproc)*2)) TARGET=arm-linux-gnueabihf scripts/build_kernel.sh "${DEVICE}" diags
			cp -v "kernel/out/${DEVICE}/uImage-diags" "${GITDIR}/out/release/uImage-diags"
			root_command dd if="kernel/out/${DEVICE}/uImage-diags" of=/dev/nbd0 bs=512 seek=19456
		fi
	elif [ "${DEVICE}" == "n236" ] || [ "${DEVICE}" == "n437" ] || [ "${DEVICE}" == "n306" ] || [ "${DEVICE}" == "n306c" ]; then
		env GITDIR="${PWD}" TOOLCHAINDIR="${PWD}/toolchain/arm-nickel-linux-gnueabihf" THREADS=$(($(nproc)*2)) TARGET=arm-nickel-linux-gnueabihf scripts/build_kernel.sh "${DEVICE}" std
		env GITDIR="${PWD}" TOOLCHAINDIR="${PWD}/toolchain/arm-nickel-linux-gnueabihf" THREADS=$(($(nproc)*2)) TARGET=arm-nickel-linux-gnueabihf scripts/build_kernel.sh "${DEVICE}" root
	elif [ "${DEVICE}" == "n249" ]; then
		env GITDIR="${PWD}" TOOLCHAINDIR="${PWD}/toolchain/armv7l-linux-musleabihf-cross" THREADS=$(($(nproc)*2)) TARGET=armv7l-linux-musleabihf scripts/build_kernel.sh "${DEVICE}" std
		env GITDIR="${PWD}" TOOLCHAINDIR="${PWD}/toolchain/armv7l-linux-musleabihf-cross" THREADS=$(($(nproc)*2)) TARGET=armv7l-linux-musleabihf scripts/build_kernel.sh "${DEVICE}" root
	fi

	if [ "${DEVICE}" == "n306" ] || [ "${DEVICE}" == "n306c" ] || [ "${DEVICE}" == "n249" ]; then
		cp -v "kernel/out/${DEVICE}/zImage-std" "${GITDIR}/out/release/zImage-std"
		cp -v "kernel/out/${DEVICE}/zImage-root" "${GITDIR}/out/release/zImage-root"
	else
		cp -v "kernel/out/${DEVICE}/uImage-std" "${GITDIR}/out/release/uImage-std"
		cp -v "kernel/out/${DEVICE}/uImage-root" "${GITDIR}/out/release/uImage-root"
	fi

	if [ "${DEVICE}" == "n249" ]; then
		cp "kernel/out/${DEVICE}/${KERNEL_FILE}" "${MOUNT_BASEPATH}/boot/zImage"
		cp "kernel/out/${DEVICE}/${DTB_FILE}" "${MOUNT_BASEPATH}/boot"
		cp "kernel/out/${DEVICE}/${BOOTSCRIPT_FILE}" "${MOUNT_BASEPATH}/boot"
	else
		root_command dd if="kernel/out/${DEVICE}/${KERNEL_FILE}" of=/dev/nbd0 bs=512 seek=81920
	fi

	if [ "${KERNEL_TYPE}" == "root" ]; then
		printf "rooted" | root_command dd of=/dev/nbd0 bs=512 seek=79872
	fi
	popd
}

setup_boot() {
	printf "==== Populating boot partition ====\n"
	root_command mkdir -p "${MOUNT_BASEPATH}/boot/flags/"
	printf "true\n" | root_command tee -a "${MOUNT_BASEPATH}/boot/flags/FIRST_BOOT"
	printf "true\n" | root_command tee -a "${MOUNT_BASEPATH}/boot/flags/X11_START"
}

setup_rootfs() {
	printf "==== Populating root filesystem partition ====\n"
	pushd out/
	git clone "${GIT_BASE_URL}/rootfs" && pushd rootfs/
	env GITDIR="${PWD}" ./release.sh && popd
	openssl dgst -sha256 -sign "${PKEY}" -out "${GITDIR}/sd/overlaymount-rootfs.squashfs.dgst" "${GITDIR}/sd/overlaymount-rootfs.squashfs"
	root_command cp -v "${GITDIR}/sd/overlaymount-rootfs.squashfs" "${GITDIR}/sd/overlaymount-rootfs.squashfs.dgst" "${MOUNT_BASEPATH}/rootfs"
	openssl dgst -sha256 -sign "${PKEY}" -out rootfs.squashfs.dgst rootfs.squashfs
	root_command cp -v "rootfs.squashfs" "rootfs.squashfs.dgst" "${MOUNT_BASEPATH}/rootfs"
	sync
	pushd release/ && root_command tar -I 'xz -9 -T0' -cvf rootfs-partition.tar.xz -C "${MOUNT_BASEPATH}/rootfs" . && popd
	sync
	popd
}

setup_user() {
	printf "==== Populating user data partition ====\n"
	pushd out/
	mkdir -p user/ && pushd user/
	# cp /home/build/inkbox/emu/sd/user.sqsh.* .
	wget "https://github.com/Kobo-InkBox/emu/blob/main/sd/user.sqsh.a?raw=true" -O "user.sqsh.a"
	wget "https://github.com/Kobo-InkBox/emu/blob/main/sd/user.sqsh.b?raw=true" -O "user.sqsh.b"
	wget "https://github.com/Kobo-InkBox/emu/blob/main/sd/user.sqsh.c?raw=true" -O "user.sqsh.c"
	wget "https://github.com/Kobo-InkBox/emu/blob/main/sd/user.sqsh.d?raw=true" -O "user.sqsh.d"
	cat user.sqsh.* > user.sqsh
	sync
	root_command unsquashfs -f -d "${MOUNT_BASEPATH}/user" user.sqsh && sync && popd

	# GUI rootfs base
	git clone "${GIT_BASE_URL}/gui-rootfs" && pushd gui-rootfs/
	env GITDIR="${PWD}" ./release.sh && popd
	cp -v "gui_rootfs.isa" "${MOUNT_BASEPATH}/user/gui_rootfs.isa"

	root_command openssl dgst -sha256 -sign "${PKEY}" -out "${MOUNT_BASEPATH}/user/gui_rootfs.isa.dgst" "${MOUNT_BASEPATH}/user/gui_rootfs.isa"
	CURRENT_VERSION=$(wget -q -O - "${PKGS_BASE_URL}/bundles/inkbox/native/update/ota_current")
	printf "%s\n" "${CURRENT_VERSION}" | root_command tee -a "${MOUNT_BASEPATH}/user/update/version"
	wget "${PKGS_BASE_URL}/bundles/inkbox/native/update/${CURRENT_VERSION}/${DEVICE}/inkbox-update-${CURRENT_VERSION}.upd.isa"
	unsquashfs "inkbox-update-${CURRENT_VERSION}.upd.isa" -extract-file update.isa

	# Replace the keys in update.isa
	cd squashfs-root/
	unsquashfs -d update_inkbox update.isa
	rm -f update.isa
	cd update_inkbox/
	rm -f inkbox.isa.dgst
	rm -f qt.isa.dgst
	openssl dgst -sha256 -sign "${PKEY}" -out qt.isa.dgst qt.isa
	openssl dgst -sha256 -sign "${PKEY}" -out inkbox.isa.dgst inkbox.isa
	mksquashfs . ../update.isa -b 1048576 -comp gzip -always-use-fragments
	cd ../../

	root_command cp -v squashfs-root/update.isa "${MOUNT_BASEPATH}/user/update/update.isa"
	sync
	rm -rf squashfs-root/
	root_command rm -rf "${MOUNT_BASEPATH}/user/config"
	root_command mkdir -p "${MOUNT_BASEPATH}/user/config"
	root_command tar -xvf "${GITDIR}/sd/config-${DEVICE}.tar.xz" -C "${MOUNT_BASEPATH}/user/config"
	sync
	pushd release/ && root_command tar -I 'xz -9 -T0' -cvf user-partition.tar.xz -C "${MOUNT_BASEPATH}/user" . && popd
	sync
	popd
}

setup_recoveryfs() {
	printf "==== Populating recovery filesystem partition ====\n"
	pushd out/
	git clone "${GIT_BASE_URL}/recoveryfs" && pushd recoveryfs/

	root_command cp -v "${GITDIR}/out/release/rootfs-partition.tar.xz" opt/recovery/restore/rootfs-part.tar.xz
	root_command cp -v "${GITDIR}/out/release/user-partition.tar.xz" opt/recovery/restore/userstore.tar.xz
	root_command cp -v "${GITDIR}/sd/config-${DEVICE}.tar.xz" opt/recovery/restore/config.tar.xz
	root_command cp -v "${GITDIR}/out/release/u-boot_inkbox.bin" opt/recovery/restore/u-boot_inkbox.bin
	if [ "${DEVICE}" == "n306" ] || [ "${DEVICE}" == "n306c" ] || [ "${DEVICE}" == "n249" ]; then
		root_command cp -v "${GITDIR}/out/release/zImage-std" opt/recovery/restore/zImage-std
		root_command cp -v "${GITDIR}/out/release/zImage-root" opt/recovery/restore/zImage-root
	else
		root_command cp -v "${GITDIR}/out/release/uImage-std" opt/recovery/restore/uImage-std
		root_command cp -v "${GITDIR}/out/release/uImage-root" opt/recovery/restore/uImage-root
	fi
	[ -f "${GITDIR}/out/release/uImage-diags" ] && root_command cp -v "${GITDIR}/out/release/uImage-diags" opt/recovery/restore/uImage-diags

	env GITDIR="${PWD}" ./release.sh && popd
	openssl dgst -sha256 -sign "${PKEY}" -out "${GITDIR}/sd/overlaymount-rootfs.squashfs.dgst" "${GITDIR}/sd/overlaymount-rootfs.squashfs"
	root_command cp -v "${GITDIR}/sd/overlaymount-rootfs.squashfs" "${GITDIR}/sd/overlaymount-rootfs.squashfs.dgst" "${MOUNT_BASEPATH}/recoveryfs"
	openssl dgst -sha256 -sign "${PKEY}" -out recoveryfs.squashfs.dgst recoveryfs.squashfs
	root_command cp -v "recoveryfs.squashfs" "recoveryfs.squashfs.dgst" "${MOUNT_BASEPATH}/recoveryfs"
	sync

	popd
}

pack_image() {
	printf "==== Packing final image ====\n"
	pushd out/release/
	root_command dd if=/dev/nbd0 status=progress of="inkbox-${CURRENT_VERSION}-${DEVICE}.img"
	sync
	popd
}

cleanup() {
	printf "==== Cleaning up ====\n"
	root_command umount "${MOUNT_BASEPATH}/boot" "${MOUNT_BASEPATH}/recoveryfs" "${MOUNT_BASEPATH}/rootfs" "${MOUNT_BASEPATH}/user"
	root_command qemu-nbd --disconnect /dev/nbd0
	rm -rf "${MOUNT_BASEPATH}"
}

case "${1}" in
	n705)
		DEVICE="n705"
		;;
	n905b)
		DEVICE="n905b"
		;;
	n905c)
		DEVICE="n905c"
		;;
	n613)
		DEVICE="n613"
		;;
	n236)
		DEVICE="n236"
		;;
	n437)
		DEVICE="n437"
		;;
	n306)
		DEVICE="n306"
		;;
	n306c)
		DEVICE="n306c"
		;;
	n249)
		DEVICE="n249"
		;;
	*)
		printf "%s is not a valid device! Available options are: n705, n905b, n905c, n613, n236, n437, n306, n306c, n249" "${1}" && exit 1
esac

build_base_sd_image
setup_u_boot
mount_fs
setup_kernel
setup_boot
setup_rootfs
setup_user
setup_recoveryfs
pack_image
cleanup
printf "==== All done! ====\n"
