#!/bin/bash
declare -a filesArray
sourceFileList="/etc/backupFileList"
destNewDir=/root/operation/new/
destOldDir=/root/operation/old/
operationDate=$(date +%Y%m%d-%H%M)
operationVM=$(hostname)
destRoot=/root/operation/
hashFile=/root/operation/hashFile
diffFile=/root/operation/diffFile
destNewDirList=/root/operation/destNewDirList
diffFn=diffFile
excludeFileList=/etc/compareBackupExcludeList
backupDir=/root/backup/
tarBackupFileName="$operationVM"-"$operationDate".tar.gz
###sourceFileList example
###on /etc/backupFileList
##remove below '#'
##conf /etc/passwd
##conf /home/ms
##code /etc/ssh/
##code /root/slapd.txt
##data /var/log/secure
##data /var/log/messages
##data /var/log/audit/




if [ ! -e "$destRoot" ];then
	mkdir -p "$destRoot"
fi

if [ ! -e "$sourceFileList" ];then
	exit 101
fi

if [ ! -e "$hashFile" ];then
	touch /root/operation/diffFile
fi

if [ ! -e "$hashFile" ];then
	touch /root/operation/hashFile
fi

if [ ! -e "$backupDir" ];then
	mkdir -p "$backupDir"
fi

if [ ! -e "$destOldDir" ];then
	mkdir -p "$destOldDir"
fi

if [ ! -e "$destNewDir" ];then
	mkdir -p "$destNewDir"
fi

cd "$destRoot" || exit 102


##read source Files List to fileSArray
##cp those file to $destNewDir
##cp --parents perserve full path
##cp -r for recursive
##cp --perserve=all perserve selinux and mode owner
while IFS= read -r filesArray
do
	if 
		echo "$filesArray"|grep '#' &>/dev/null  
	then
		continue
	fi
	
	backupType=$(echo "${filesArray}"|awk '{print $1}')
	backupFileOnAWK=$(echo "${filesArray}"|awk '{print $2}')
	if [ ! -e "$destNewDir$backupType" ];then
		mkdir -p "$destNewDir$backupType"
	fi
	cp --parents -r --preserve=all "$backupFileOnAWK" "$destNewDir$backupType"
done < "$sourceFileList"

cd "$destNewDir" || exit 103
find ./ -maxdepth 1 -mindepth 1 -type d | cut -c3- >"$destNewDirList"

while IFS= read -r dirName
do
	##WITH OUT $destOldDir move new to old
	##and package the old then compute md5
	##Here tar -P perserve lead /
	##and -p perserve permission
	if [ ! -d "$destOldDir$dirName" ];then
		mv "$destNewDir$dirName" "$destOldDir$dirName" && \
		tar --selinux -zPpcf "$dirName-$tarBackupFileName" "$destOldDir$dirName" && \
		md5sum "$dirName-$tarBackupFileName" >>"$hashFile" && \
		mv "$dirName-$tarBackupFileName" "$backupDir/"


	###with $destOldDir,compare between old and new
	###if new equal old then delete new
	###if new Not equal old then delete old
	###then move new to old
	###then package old and compute md5
	else	
		if diff --exclude-from="$excludeFileList" --exclude="$diffFn" -ur \ 
		"$destNewDir$dirName" "$destOldDir$dirName" >"$diffFile"
		then
			rm -rf "$destNewDir$dirName"
		else rm -rf "$destOldDir$dirName" && \
			mv "$destNewDir$dirName" "$destOldDir$dirName" && \
			cp "$diffFile" "$destOldDir$dirName" && \
			tar --selinux -zPpcf "$dirName-$tarBackupFileName" "$destOldDir$dirName" && \
			md5sum "$dirName-$tarBackupFileName" >>$hashFile && \
			mv "$dirName-$tarBackupFileName" "$backupDir/"
		fi
	fi
done < "$destNewDirList"
