process CREATE_GENES_DB {

    publishDir "${params.outdir}/genes_db", mode: 'copy'

    container 'quay.io/biocontainers/python:3.11'

    tag "$gtf"

    input:
    path gtf

    output:
    path 'genes.db', emit: db
    path 'versions.yml', emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    python3.11 ${moduleDir}/scripts/create_genes_db.py \
        makedb \
        -db $gtf \
        genes.db

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3.11 --version | cut -d' ' -f2)
    END_VERSIONS
    """

}