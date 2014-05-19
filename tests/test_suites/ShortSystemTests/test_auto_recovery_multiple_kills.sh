timeout_set 5 minutes
CHUNKSERVERS=1 \
	MFSEXPORTS_EXTRA_OPTIONS="allcanchangequota,ignoregid" \
	MOUNT_EXTRA_CONFIG="mfsacl" \
	MASTER_EXTRA_CONFIG="MAGIC_DISABLE_METADATA_DUMPS = 1|AUTO_RECOVERY = 1" \
	USE_RAMDISK="YES" \
	setup_local_empty_lizardfs info

for generator in $(metadata_get_all_generators); do
	export MESSAGE="Testing generator $generator"

	# Remember version of the metadata file. We expect it not to change when generating data.
	metadata_version=$(metadata_get_version "${info[master_data_path]}"/metadata.mfs)

	# Generate some content using the current generator and remember its metadata
	cd "${info[mount0]}"
	eval "$generator"
	metadata=$(metadata_print)
	cd

	# Simulate crash of the master server
	lizardfs_master_daemon kill

	# Make sure changes are in changelog only (ie. that metadata wasn't dumped)
	assert_equals "$metadata_version" "$(metadata_get_version "${info[master_data_path]}"/metadata.mfs)"

	# Restore the filesystem from changelog by starting master server and check it
	assert_success lizardfs_master_daemon start
	lizardfs_wait_for_all_ready_chunkservers
	cd "${info[mount0]}"
	assert_no_diff "$metadata" "$(metadata_print)"
	cd
done

# Check if we can read files
cd "${info[mount0]}"
metadata_validate_files
