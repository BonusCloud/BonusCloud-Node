#!/bin/sh

MMCPATH="/mnt/mmc"
FILEPATH="/boot/bcloud.tar.gz"
MMC_BLOCK1="/dev/mmcblk1p2"
MMC_BLOCK2="/dev/mmcblk0p2"
MMC_BLOCK3="/dev/mmcblk0"


if [ -b $MMC_BLOCK1 ]; then
	mount $MMC_BLOCK1 $MMCPATH
elif [ -b $MMC_BLOCK2 ]; then
	echo "found $MMC_BLOCK2"
	mount $MMC_BLOCK2 $MMCPATH
elif [ -b $MMC_BLOCK3 ]; then
	echo "Found $MMC_BLOCK3 and not found $MMC_BLOCK1 or $MMC_BLOCK2"
	mount -o loop,offset=$((512*1619968)) $MMC_BLOCK3 $MMCPATH
else
	echo "emmc  not found"
	exit 1
fi

if [ -d "$MMCPATH"/opt ]; then
	echo "mount emmc success!"
else
	echo "mount emmc failed!"
fi


backup(){
    cd $MMCPATH/opt
    tar -cvzp -f $FILEPATH bcloud 
    res=`echo $?`
    if [ "$res" != 0 ] ;then
        echo "$res"
        echo "$1 failed "
        echo "备份失败"
    else
        echo "$1 success!"
        echo "备份成功"
        echo "backup file save to $FILEPATH"
        echo "备份文件已保存至 $FILEPATH"
    fi
    cd ~
}
restore(){
    tar -xvz -f $FILEPATH -C $MMCPATH/opt 
    res=`echo $?`
    if [ "$res" != 0 ] ;then
        echo "$1 failed "
        echo "还原失败"
    else
        echo "$1 success!"
        echo "还原成功"
    fi
}

help(){
    echo "Input 'sh $0 backup' or 'sh $0 restore'"
    echo "输入'sh $0 backup' 备份 或者 'sh $0 restore' 还原"
}

case $1 in
    backup )
        backup $1
        ;;
    restore )
        restore $1
        ;;
    * )
        help
        ;;
esac
umount $MMCPATH
