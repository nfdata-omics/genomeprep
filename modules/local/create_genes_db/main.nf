process CREATE_GENES_DB {

    publishDir "${params.outdir}/genes_db", mode: 'copy'

    container = 'docker.io/nfdata/genes-db:v1.0.0'

    containerOptions = workflow.containerEngine == 'docker' ?
        '--platform=linux/amd64 --entrypoint=""' : ''


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
    #!/bin/bash
    set -euo pipefail

    python3.11 /app/create_genes_db.py \
        makedb \
        -db $gtf \
        genes.db

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3.11 --version | cut -d' ' -f2)
    END_VERSIONS
    """

}
