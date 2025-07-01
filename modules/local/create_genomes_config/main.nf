process CREATE_GENOMES_CONFIG {

    publishDir "${params.outdir}/genomes_config", mode: 'copy'

    tag "$genome_version_name"

    conda "${moduleDir}/environment.yml"
    // create containers

    input:
    val genome_version_name
    path current_config_file
    path fasta
    path bowtie2_index
    path bwa_index
    path gatk4_dict
    path samtools_index
    path star_index
    path gtf

    output:
    path "genomes.config", emit: config

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    def outdir_abs = java.nio.file.Paths.get(params.outdir.toString()).toAbsolutePath().toString()

    def fasta_abs = "$outdir_abs/fasta/$fasta"
    def bwa_abs = "$outdir_abs/$bwa_index/"
    def bowtie2_abs = "$outdir_abs/$bowtie2_index/"
    def gatk_abs = "$outdir_abs/$gatk4_dict"
    def samtools_abs = "$outdir_abs/$samtools_index/"
    def star_abs = "$outdir_abs/$star_index/"
    def gtf_abs = "$outdir_abs/genes/$gtf"

    def config_file = "${outdir_abs}/genomes.config"
    """
    mkdir -p $outdir_abs/fasta
    cp $fasta $outdir_abs/fasta/

    mkdir -p $outdir_abs/genes
    cp $gtf $outdir_abs/genes/

    python3.11 ${moduleDir}/scripts/build_config.py \
        --genomeVersionName $genome_version_name \
        --currentConfigFile $current_config_file \
        --fasta $fasta_abs \
        --bwa $bwa_abs \
        --bowtie2 $bowtie2_abs \
        --gatk $gatk_abs \
        --samtools $samtools_abs \
        --star $star_abs \
        --gtf $gtf_abs \
        --outputFile $config_file \
        $args
    """
}