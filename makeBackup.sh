#!/bin/bash

are_there_necessary_arguments=0
need_check_sums=1
need_set_backup_frequency=1
need_deleting_old_backups=1

while getopts ": d:e:w:sp:n:h" opt
do
	case $opt in
	d) directory_for_archiving=$OPTARG
		are_there_necessary_arguments=$((are_there_necessary_arguments+1));;
	e) extension=$OPTARG
		are_there_necessary_arguments=$((are_there_necessary_arguments+1));;
	w) where_save_archive=$OPTARG
		are_there_necessary_arguments=$((are_there_necessary_arguments+1));;
	s) need_check_sums=0;;
	p) need_set_backup_frequency=0
		frequency_of_backup=$OPTARG
		if ! (echo "$frequency_of_backup" | grep -E -q "^[0-9]+$")
		then
			echo "-p argument is not number"
			exit 1
		fi;;
	n) need_deleting_old_backups=0
		maximum_number_of_backups=$OPTARG
		if ! (echo "$maximum_number_of_backups" | grep -E -q "^[0-9]+$")
		then
			echo "-n argument is not number"
			exit 1
		fi;;
	h) echo "Usage: ./MAKEBACKUP.sh [OPTIONS] -d ARCHIVED_DIRECTORY -e FILE_EXTENSION -w STORAGE"
		echo
		echo "(the different order of parameters can be used)"
		echo
		echo "Backup files with the specified extension to the specified directory"
		echo
		echo "List of options"
		echo "	-d  Directory with files to archive is specified after the key"
		echo
		echo "	-e  The extension of the archived file is specified after the key"
		echo
		echo "	-w  The directory where the backup is saved"
		echo
		echo "	-s	Checking checksums"
		echo
		echo "	-p	Frequency of copying: after the key, specify the frequency as a number,"
		echo "		suffix may be 's' for seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days"
		echo
		echo "	-n	Deleting old backups: the maximum number of stored copies is specified after the key."
		echo "		If the maximum number of backups already exists in the storage location,"
		echo "		the oldest ones are deleted and a new copy is created"
		echo
		echo "	-h	Display help and exit"
		exit 0 ;;
	:) echo "$OPTARG must have an argument!"
		echo "Use -h for help"
		exit 1;;
	*) echo "A nonexistent key is specified!"
		echo "Use -h for help"
		exit 1;;
	esac
done

if [ $are_there_necessary_arguments -ne 3 ]
then
	echo "Script usage error!"
	echo "Use -h for help"
	exit 1
fi


while true
do
	if [[ ! -d $directory_for_archiving ]]
	then
		echo "Directory $directory_for_archiving doesn't exist"
		exit 1
	fi
	if [[ ! -d $where_save_archive ]]
	then
		echo "Directory $where_save_archive doesn't exist"
		exit 1
	fi
	checksums="$where_save_archive/checksums"
	if [[ ! -d $checksums ]]
	then
		mkdir "$checksums"
	fi
	list_of_all_backups="$where_save_archive/list_of_all_backups"
	if [[ ! -f $list_of_all_backups ]]
	then
		touch "$list_of_all_backups"
	fi
	
	name_for_archive=$RANDOM
	while [[ -e "$directory_for_archiving/$name_for_archive.zip" ]] || [[ -e "$where_save_archive/$name_for_archive.zip" ]]
	do
		name_for_archive=$RANDOM
	done
	
	files_for_to_archive=$(find "$directory_for_archiving" -name "*.""$extension""")
	if [[ -z $files_for_to_archive ]]
	then
		exit 0
	fi
	sums="$where_save_archive/checksums/sums$name_for_archive.md5"
	touch "$sums"
	md5sum $files_for_to_archive | cut -f 1 -d " " > "$sums"

	zip "$where_save_archive/$name_for_archive" -r "$directory_for_archiving" -i "*.""$extension"""
	
	if [[ $need_check_sums -eq 0 ]]
	then
		tempdir="$checksums/tempdir"
		mkdir "$tempdir"
		unzip "$where_save_archive/$name_for_archive" -d "$tempdir"
		tempsum="$checksums/temp$name_for_archive.md5"
		md5sum $(find "$tempdir" -name "*.""$extension""") | cut -f 1 -d " "  > "$tempsum"
		rm -r -f "$tempdir"
		
		if cmp -s "$sums" "$tempsum"
		then
			echo "The checksums are the same!"
			rm "$tempsum"
		else
			echo "The checksums don't match!"
		fi		
	fi
	
	if [[ "$need_deleting_old_backups" -eq 0 ]] && [[ "$maximum_number_of_backups" -ge 0 ]]
	then
		number_of_deleted_files=$(< "$list_of_all_backups" wc -l)
		number_of_deleted_files=$((number_of_deleted_files-maximum_number_of_backups+1))
		for deleted_file in $(cat "$list_of_all_backups")
		do
			if [[ $number_of_deleted_files -le 0 ]]
			then
				break
			fi
			if [[ -f "$where_save_archive/$deleted_file.zip" ]]
			then
				rm "$where_save_archive/$deleted_file.zip"
				rm "$where_save_archive/checksums/sums$deleted_file.md5"
			fi
			number_of_deleted_files=$((number_of_deleted_files-1))
		done
	fi
		
	echo $name_for_archive >> "$list_of_all_backups"

	if [[ $need_set_backup_frequency -eq 1 ]]
	then
		break
	else
		sleep "$frequency_of_backup"
	fi
done
