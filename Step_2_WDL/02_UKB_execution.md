# Running the Workflow on UKB RAP

## Single sample execution

To run the workflow ('hla_la_wf.wdl') on a sinlge sample:

```bash
dx run UKB/directory/of/stored/workflow \
    -i stage-common.cram_file="[UKB Project ID]:[UKB Unique File ID]" \
    -i stage-common.cram_index="[UKB Project ID]:[UKB Unique File ID]" \
    -i stage-common.ref_genome="[UKB Project ID]:[UKB Unique File ID]" \
    -i stage-common.ref_genome_index="[UKB Project ID]:[UKB Unique File ID]" \
    -i stage-common.ref_genome_gzi="[UKB Project ID]:[UKB Unique File ID]" \
    -i stage-common.nr_threads=8 \
    --priority high \ #adjust for priority 'low', 'normal', or 'high'
    --destination=UKB/directory/to/store/results
```

