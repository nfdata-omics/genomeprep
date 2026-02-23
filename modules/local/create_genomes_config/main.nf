process CREATE_GENOMES_CONFIG {

    tag "$genome_version_name"

    conda "${moduleDir}/environment.yml"
    container 'docker.io/nfdata/genome-config:v1.12.0'

    input:
    val base_dir
    val genome_version_name
    path current_config_file
    val source
    val taxid
    val organism
    path fasta
    path kallisto_index
    path minimap2_index
    path hisat2_index
    path bowtie2_index
    path bwa_index
    path gatk4_dict
    path samtools_index
    path star_index
    path bismark_index
    path chrom_sizes
    path readme
    path rsem
    path salmon_index
    path db
    path bed
    path gtf
    path cellranger
    path atac
    path vdj
    path spaceranger

    output:
    path "genomes_config", emit: config
    path "fasta", emit: fasta
    path "genes", emit: genes
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    def script_path = workflow.containerEngine ? "/opt/app/build_config.py" : "${moduleDir}/scripts/build_config.py"

    def outdir_abs = java.nio.file.Paths.get(params.outdir.toString()).toAbsolutePath().toString()

    def fasta_abs = "$outdir_abs/fasta/$fasta"
    def kallisto_abs = "$outdir_abs/$kallisto_index"
    def minimap2_abs = "$outdir_abs/$minimap2_index"
    def hisat2_abs = "$outdir_abs/$hisat2_index/hisat2"
    def bwa_abs = "$outdir_abs/$bwa_index/bwa/"
    def bowtie2_abs = "$outdir_abs/$bowtie2_index/bowtie2/"
    def gatk_abs = "$outdir_abs/gatk4/$gatk4_dict"
    def samtools_abs = "$outdir_abs/samtools/$samtools_index"
    def star_abs = "$outdir_abs/$star_index/star/"
    def bismark_abs = "$outdir_abs/bismark/$bismark_index/"
    def readme_abs = "$outdir_abs/readme/$readme"
    def chrom_sizes_abs = "$outdir_abs/chromosomes_sizes/$chrom_sizes"
    def gtf_abs = (gtf.name != "no_gtf") ? "$outdir_abs/genes/$gtf" : ""
    def cellranger_abs = (cellranger.name != "no_cellranger") ? "$outdir_abs/cellranger/$cellranger/" : ""
    def atac_abs = (atac.name != "no_atac") ? "$outdir_abs/cellrangeratac/$atac/" : ""
    def vdj_abs = (vdj.name != "no_cellranger_vdj") ? "$outdir_abs/cellranger/$vdj/" : ""
    def spaceranger_abs = (spaceranger.name != "no_spaceranger") ? "$outdir_abs/spaceranger/$spaceranger/" : ""
    def rsem_abs = (rsem.name != "no_rsem") ? "$outdir_abs/rsem/$rsem/" : ""
    def salmon_abs = (salmon_index.name != "no_salmon") ? "$outdir_abs/salmon/$salmon_index/" : ""
    def db_abs = (db.name != "no_genes_db") ? "$outdir_abs/genes_db/$db" : ""
    def bed_abs = (bed.name != "no_bed") ? "$outdir_abs/bed_files/bed/genes.bed" : ""
    def current_config_file_abs = (current_config_file.name != "no_current_config_file") ? current_config_file : ""

    def config_file = "genomes_config/genomes.config"

    def base_dir_path = (base_dir != "no_provided_base_dir") ? base_dir : "$outdir_abs"
    def gtf_args = (gtf.name != 'no_gtf') ? "--gtf $gtf_abs" : ""
    def cellranger_args = (cellranger.name != 'no_cellranger') ? "--cellranger $cellranger_abs" : ""
    def atac_args = (atac.name != 'no_atac') ? "--cellranger_atac $atac_abs" : ""
    def vdj_args = (vdj.name != 'no_cellranger_vdj') ? "--cellranger_vdj $vdj_abs" : ""
    def spaceranger_args = (spaceranger.name != 'no_spaceranger') ? "--spaceranger $spaceranger_abs" : ""
    def rsem_args = (rsem.name != 'no_rsem') ? "--rsem $rsem_abs" : ""
    def salmon_args = (salmon_index.name != 'no_salmon') ? "--salmon $salmon_abs" : ""
    def db_args = (db.name != 'no_genes_db') ? "--gene_db $db_abs" : ""
    def bed_args = (bed.name != 'no_bed') ? "--bed12 $bed_abs" : ""
    def hisat2_args = (hisat2_index.name != 'no_hisat2') ? "--hisat2 $hisat2_abs" : ""
    def current_config_file_args = (current_config_file.name != 'no_current_config_file') ? "--current_config_file $current_config_file_abs" : ""
    """
    #!/bin/bash
    set -euo pipefail

    mkdir -p genomes_config

    if [ "$gtf" != "no_gtf" ]; then
        mkdir -p genes
        cp $gtf genes/
    fi

    mkdir -p fasta
    cp $fasta fasta/

    echo "Config file: $current_config_file_args"

    python3.11 $script_path \
        --base_dir $base_dir_path \
        --source '$source' \
        --taxid '$taxid' \
        --organism '$organism' \
        --genome_version_name $genome_version_name \
        $current_config_file_args \
        --fasta $fasta_abs \
        --bwa $bwa_abs \
        --bowtie2 $bowtie2_abs \
        --gatk $gatk_abs \
        --samtools $samtools_abs \
        --star $star_abs \
        --bismark $bismark_abs \
        --chrom_sizes $chrom_sizes_abs \
        --readme $readme_abs \
        --kallisto $kallisto_abs \
        --minimap2 $minimap2_abs \
        $hisat2_args \
        $cellranger_args \
        $atac_args \
        $vdj_args \
        $spaceranger_args \
        $gtf_args \
        $rsem_args \
        $salmon_args \
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
