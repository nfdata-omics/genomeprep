process CREATE_GENOMES_CONFIG {

    publishDir "${params.outdir}/genomes_config", mode: 'copy'

    tag "$genome_version_name"

    conda "${moduleDir}/environment.yml" 
    container 'gitlab.fht.org:5050/nfdata-omics/genome-config:test'
    containerOptions = '--platform=linux/amd64 --entrypoint=""'

    input:
    val genome_version_name
    path current_config_file
    path fasta
    path bowtie2_index
    path bwa_index
    path gatk4_dict
    path samtools_index
    path star_index
    path bismark_index
    path rsem
    path db
    path bed
    path gtf

    output:
    path "genomes.config", emit: config
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    def script_path = workflow.containerEngine ? "/opt/app/build_config.py" : "${moduleDir}/scripts/build_config.py"

    def outdir_abs = java.nio.file.Paths.get(params.outdir.toString()).toAbsolutePath().toString()

    def fasta_abs = "$outdir_abs/fasta/$fasta"
    def bwa_abs = "$outdir_abs/$bwa_index/"
    def bowtie2_abs = "$outdir_abs/$bowtie2_index/"
    def gatk_abs = "$outdir_abs/$gatk4_dict"
    def samtools_abs = "$outdir_abs/$samtools_index/"
    def star_abs = "$outdir_abs/$star_index/"
    def bismark_abs = "$outdir_abs/$bismark_index/"
    def gtf_abs = (gtf.name != "no_gtf") ? "$outdir_abs/genes/$gtf" : ""
    def rsem_abs = (rsem.name != "no_rsem") ? "$outdir_abs/$rsem" : ""
    def db_abs = (db.name != "no_genes_db") ? "$outdir_abs/$db" : ""
    def bed_abs = (bed.name != "no_bed") ? "$outdir_abs/$bed" : ""

    def config_file = "${outdir_abs}/genomes.config"

    def gtf_args = (gtf.name != 'no_gtf') ? "--gtf $gtf_abs" : ""
    def rsem_args = (rsem.name != 'no_rsem') ? "--rsem $rsem_abs" : ""
    def db_args = (db.name != 'no_genes_db') ? "--gene_db $db_abs" : ""
    def bed_args = (bed.name != 'no_bed') ? "--bed12 $bed_abs" : ""
    
    """
    #!/bin/bash
    set -euo pipefail

    if [ "$gtf" != "no_gtf" ]; then
        mkdir -p $outdir_abs/genes
        cp $gtf $outdir_abs/genes/
    fi

    mkdir -p $outdir_abs/fasta
    cp $fasta $outdir_abs/fasta/

    echo "gtf_args: $gtf_args"
    echo "rsem_args: $rsem_args"


    python3.11 $script_path \
        --genome_version_name $genome_version_name \
        --current_config_file $current_config_file \
        --fasta $fasta_abs \
        --bwa $bwa_abs \
        --bowtie2 $bowtie2_abs \
        --gatk $gatk_abs \
        --samtools $samtools_abs \
        --star $star_abs \
        --bismark $bismark_abs \
        $gtf_args \
        $rsem_args \
        $db_args \
        $bed_args \
        --output_file $config_file \
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3.11 --version | cut -d' ' -f2)
        pydantic: \$(python3.11 -c "import pydantic; print(pydantic.VERSION)")
    END_VERSIONS
    """
}