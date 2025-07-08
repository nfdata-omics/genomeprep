process HANDLE_README {

    publishDir "${params.outdir}/readme", mode: 'copy'

    tag "$fasta_readme, $gtf_readme"

    input:
    path fasta_readme
    path gtf_readme
    val genome_version_name
    path current_config_file

    output:
    path 'README.md', emit: readme

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    echo "# Genome Preparation Pipeline" > README.md
    echo "This pipeline prepares a genome for analysis by various tools. The Nextflow/nf-core code can be found at https://github.com/nfdata-omics/genomeprep." >> README.md
    echo "" >> README.md

    echo "## Input Files" >> README.md
    echo "- Fasta file: \n \t `cat $fasta_readme`" >> README.md
    if [ "\$(basename "$gtf_readme")" != "no_gtf_readme" ]; then
        echo "- GTF file: \n \t `cat $gtf_readme`" >> README.md
    else
        echo "- GTF file: \n \t Not provided" >> README.md
    fi
    echo "- Genome version name: \n \t $genome_version_name" >> README.md
    echo "- Previous configuration file: \n \t $current_config_file" >> README.md
    echo "" >> README.md

    echo "## Previous Configuration" >> README.md
    if [ -f "$current_config_file" ]; then
        echo "" >> README.md
        echo "Previous configurations:" >> README.md
        echo ""
        cat "$current_config_file" >> README.md
    else
        echo "No previous configuration file provided." >> README.md
    fi
    """

}