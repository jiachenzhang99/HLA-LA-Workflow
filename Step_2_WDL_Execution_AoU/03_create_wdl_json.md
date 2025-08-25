## Create WDL File

The follwoing code creates a WDL file and stores it in the active disk:

```
wdl_filename = "hla_la_wf_aou.wdl"

WDL_content = """

version 1.0

workflow hla_la_calling_aou {
    input {
        # AoU specific inputs
        File cram_file
        File cram_index           
        
        # Reference files 
        File ref_genome            # Homo_sapiens_assembly38.fasta
        File ref_genome_index      # Homo_sapiens_assembly38.fasta.fai 
        File ref_genome_gzi        # Homo_sapiens_assembly38.fasta.gzi
        
        # Runtime parameters
        Int nr_threads         # Number of threads for HLA-LA
    }

    # Run HLA-LA typing
    call hla_la_typing {
        input: 
            cram_file = cram_file,
            cram_index = cram_index,
            ref_genome = ref_genome,
            ref_genome_index = ref_genome_index,
            ref_genome_gzi = ref_genome_gzi,
            nr_threads = nr_threads
    }

    output {
        File hla_best_guess = hla_la_typing.hla_best_guess
        File hla_all_alleles = hla_la_typing.hla_all_alleles
    }
}

task hla_la_typing {
    input {
        File cram_file
        File cram_index
        File ref_genome
        File ref_genome_index
        File ref_genome_gzi
        Int nr_threads
    }

    String cram_basename = basename(cram_file)
    String sample_id = sub(cram_basename, "\\.cram$", "")

    command <<<
        
        # Copy input files to working directory
        cp ~{cram_file} .
        cp ~{cram_index} .
        cp ~{ref_genome} .
        cp ~{ref_genome_index} .
        cp ~{ref_genome_gzi} .
        
        mkdir -p /data
        
        # Run HLA-LA typing
        type_hla.sh ~{nr_threads} ~{basename(cram_file)} ~{basename(ref_genome)}
        
        # Copy the output files from /data/ to current directory
        cp /data/~{sample_id}_output_G.txt ./ 
        cp /data/~{sample_id}_output.txt ./ 
        
    >>>

    runtime {
        docker: "jiachenzdocker/hla-la:2.0"
        memory: "64G"
        cpu: nr_threads
        disks: "local-disk 200 SSD"
        bootDiskSizeGb: 50
        preemptible: 3 
    }

    output {
        File hla_best_guess = "~{sample_id}_output_G.txt"
        File hla_all_alleles = "~{sample_id}_output.txt"
    }
}

"""

fp = open(wdl_filename, 'w')
fp.write(WDL_content)
fp.close()
print(WDL_content)
```

Create the accompanying JSON file:

```
json_filename = "hla_la_wf_aou.json"

#create the content inside the json file, listing the google bucket associated with this workspace
json_content = """
{
  "hla_la_calling_aou.cram_file": "gs://[CRAM file URI]",
  "hla_la_calling_aou.cram_index": "gs://[CRAI file URI]",
  "hla_la_calling_aou.ref_genome": "gs://[Homo_sapiens_assembly38.fasta.gz]",
  "hla_la_calling_aou.ref_genome_index": "gs://[Homo_sapiens_assembly38.fasta.gz.fai]",
  "hla_la_calling_aou.ref_genome_gzi": "gs://[Homo_sapiens_assembly38.fasta.gz.gzi]",
  "hla_la_calling_aou.nr_threads": 6
}
"""

#write to validate_vcf.json
fp = open(json_filename, 'w')
fp.write(json_content)
fp.close()
print(json_content)
```
