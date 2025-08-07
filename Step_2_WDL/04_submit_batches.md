# Execute Batch Analyses

The code below submits a given batch to RAP. It needs to be executed for each batch created in the previous step (`03_create_batches`). To simplify the process, you can use a loop to iterate through all batches.

```bash
batch_num=1 #need to submit for all batches

dx run /UKB/directory/of/stored/workflow \
--batch-tsv batch_${batch_num}.tsv \
-i stage-common.ref_genome="[project ID]:[ref file ID]" \
-i stage-common.ref_genome_index="[project ID]:[ref file ID]" \
-i stage-common.ref_genome_gzi="[project ID]:[ref file ID]" \
-i stage-common.nr_threads=8 \
--priority normal \
--brief \
--yes \
--batch-folders \
--destination=/UKB/directory/to/store/results/ \
--name "HLA-LA_batch_${batch_num}"
```
