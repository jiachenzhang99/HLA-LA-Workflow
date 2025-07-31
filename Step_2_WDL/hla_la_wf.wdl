version 1.0

workflow hla_la_calling_wf {
    input {
        File cram_file
        File cram_index        # The .crai file
        File ref_genome        # Homo_sapiens_assembly38.fasta
        File ref_genome_index  # Homo_sapiens_assembly38.fasta.fai 
        File ref_genome_gzi    # Homo_sapiens_assembly38.fasta.gzi
        Int nr_threads         # Number of threads for HLA-LA
    }

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
    String sample_id = sub(sub(cram_basename, "\\.dragen", ""), "\\.cram$", "")

    command <<<
        # Create working directory
        mkdir -p /data
        
        # Copy input files to working directory
        cp ~{cram_file} /data/
        cp ~{cram_index} /data/
        cp ~{ref_genome} /data/
        cp ~{ref_genome_index} /data/
        cp ~{ref_genome_gzi} /data/
        
        # Run HLA-LA typing
        cd /data
        type_hla.sh ~{nr_threads} ~{basename(cram_file)} ~{basename(ref_genome)}
        
        # Copy results back to working directory so WDL can find them
        cd /home/dnanexus/work
        cp /data/~{sample_id}_output_G.txt ./ 
        cp /data/~{sample_id}_output.txt ./
        
    >>>

    runtime {
        docker: "jiachenzdocker/hla-la:latest"
        dx_instance_type: "mem3_ssd1_v2_x8" #adjust for customized CPU, RAM and Storage (https://documentation.dnanexus.com/developer/api/running-analyses/instance-types)
    }

    output {
        File hla_best_guess = "~{sample_id}_output_G.txt"
        File hla_all_alleles = "~{sample_id}_output.txt"
    }
}
