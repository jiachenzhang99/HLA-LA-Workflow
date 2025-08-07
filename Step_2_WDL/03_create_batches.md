# Create Batches of WGS datafiles


Since UKB RAP stores the DRAGEN WGS data in separate folders (i.e. 10, 11, 12, ... 60), batch input is needed to run large number of sample analyses parallelly instead of manually starting the pipeline once for each of the UK Biobank participants. For best reproducibility and monitoring, the following code will be executed line by line on local machine (e.g. terminal, VScode, etc.). Column names are important and very tricky, see more here: https://documentation.dnanexus.com/user/running-apps-and-workflows/running-batch-jobs



```bash
#set environment
export LOCAL_BATCH_DIR="local/directory/to/store/batch/input/files"
CRAM_PATH="UKB/directory/of/CRAM/files"
export SAMPLES_PER_BATCH=10  #number of samples to be included in each batch, adjust to need
PROJECT_NAME="UKB project ID"

dx login

#create directories
mkdir -p ${LOCAL_BATCH_DIR}/{prelim,final,temp}

# Navigate to CRAM directory
dx cd "${CRAM_PATH}"

# Get list of folders
dx ls | grep -E '^[0-9]+/$' | sed 's/\///' > "${LOCAL_BATCH_DIR}/folders.txt"

# Process each folder with dx generate_batch_inputs
while read folder; do

  echo "Generating batch inputs for folder: ${folder}"
  
  dx generate_batch_inputs \
    -icram_file='(.*)\.dragen\.cram$' \
    -icram_index='(.*)\.dragen\.cram\.crai$' \
    --path "${CRAM_PATH}/${folder}/" \
    -o "${LOCAL_BATCH_DIR}/prelim/folder_${folder}"
done < "${LOCAL_BATCH_DIR}/folders.txt"


#process all preliminary files and create batches
shopt -s nullglob
sample_count=0
batch_counter=1
first_file_processed=false
output_dir="${LOCAL_BATCH_DIR}/final"
header_template=""
mkdir -p "${output_dir}"
current_batch_file="${output_dir}/batch_${batch_counter}.tsv"

for prelim_file in "${LOCAL_BATCH_DIR}"/prelim/folder_*.0000.tsv; do
  if ! ${first_file_processed}; then
    header_template=$(head -1 "${prelim_file}" | tr -d '\r')
    echo "${header_template}" > "${current_batch_file}"
    first_file_processed=true
  fi

  while IFS=$'\t' read -r batch_id cram_file cram_file_id cram_index cram_index_id rest; do
    if [[ -n "${cram_file_id}" && -n "${cram_index_id}" ]]; then
      if [ ${sample_count} -ge ${SAMPLES_PER_BATCH} ]; then
        echo "Completed batch ${batch_counter} with ${sample_count} samples"
        batch_counter=$((batch_counter + 1))
        sample_count=0
        current_batch_file="${output_dir}/batch_${batch_counter}.tsv"
        echo "${header_template}" > "${current_batch_file}"
      fi
      echo -e "${batch_id}\t${cram_file}\t${cram_file_id}\t${cram_index}\t${cram_index_id}" >> "${current_batch_file}"
      sample_count=$((sample_count + 1))
    fi
  done < <(tail -n +2 "${prelim_file}" | tr -d '\r')
done

if [ ${sample_count} -gt 0 ]; then
  echo "Completed batch ${batch_counter} with ${sample_count} samples"
fi

echo "All batch files created in ${output_dir}"

#change the colunmn names in the batch files
new_header="batch ID\tstage-common.cram_file\tstage-common.cram_index\tstage-common.cram_file ID\tstage-common.cram_index ID"

for file in batch_*.tsv; do
  if [ -f "$file" ]; then
    echo "Updating header for ${file}..."
    sed -i "1s/.*/${new_header}/" "${file}"
  fi
done

echo "Header update complete."


#check results
echo "Batch creation completed. Created ${batch_counter} batches."

```

