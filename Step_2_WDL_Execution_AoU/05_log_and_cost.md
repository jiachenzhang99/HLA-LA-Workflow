## Workflow Log File

In default, cromwell deletes the log file after the job succeeds or fails. To retain the log file, use the following JSON file and modfity to cromshell command as below:

```
#createa separate optional output json file
json_filename = "output_options.json"

#create the content inside the json file, listing the google bucket associated with this workspace
json_content = """
{
  "workflow-log-temporary": false,
  "final_workflow_log_dir": "gs://directory/to/store/log/file"
}
"""

#write to validate_vcf.json
fp = open(json_filename, 'w')
fp.write(json_content)
fp.close()
print(json_content)

#execute wdl with additional -op flag
!cromshell submit -op output_options.json hla_la_wf_aou.wdl hla_la_wf_aou.json
```


## Cost Estimation

After a workflow is succeeded, store the metadata locally:

```
!cromshell metadata $submission_id > metadata.json
```

Store the `estimate_cromwell_cost.py` script in the working disk space and execute the command to estimate the workflow cost:

```
!python estimate_cromwell_cost.py --metadata metadata.json --details
```

Note: The estimated cost corresponds to the actual workflow execution, which is a separate cost than the Cromwell application and Jupyter environment costs. The estimation is based on Google Cloud Batch pricing structure (us-central1 region, as of 2024/2025). This cost estimation is last updated by Jiachen Zhang on August 2025.
