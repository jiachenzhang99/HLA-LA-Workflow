## Execute WDL using Cromshell

Validate the WDL and JSON files created in step3:

```
!cromshell validate hla_la_wf_aou.wdl hla_la_wf_aou.json
```


Once the validation succeeded, execute using cromshell:

```
!cromshell submit hla_la_wf_aou.wdl hla_la_wf_aou.json
```

## Monitor Job Status

Once the wdl is submitted, a submission ID will be provided. This ID is needed to check status, retrieve output, and terminate etc. Use the following code to get the most recent submission id and store it as `submission_id`:

```
with open('/home/jupyter/.cromshell/all.workflow.database.tsv') as f:
    for line in f:
        pass
    most_recent_submission = line.strip().split('\t')
submission_id = most_recent_submission[2]
print(submission_id)
```

Check the status until succeed or fail:

```import time
def check_job_status(submission_id):
    while True:
        try:
            # Run the command and capture the output
            result = subprocess.run(
                f"cromshell status {submission_id}",
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=True,
            )
            # Extract the status from the output
            output = result.stdout
            status_start = output.find("status\":\"") + len("status\":\"")
            status_end = output.find("\"", status_start)
            status = output[status_start:status_end]

            print(f"Job status: {status}")

            if status in ["Succeeded", "Failed"]:
                break  # Job has succeeded or failed, exit the loop

        except subprocess.CalledProcessError as e:
            print(f"Error running command: {e}")
        
        time.sleep(600)  # change here for time interval (in seconds)

# Call the function to check the job status
check_job_status(submission_id)
```


The output directory will be in google bucket under `cromwell-execution`.
