process CREATE_BED_FILES {

    publishDir "${params.outdir}/bed", mode: 'copy'
    
    container 'docker.io/ubuntu:22.04'
    containerOptions '--user root'

    tag "$db"

    input:
    path db

    output:
    path '*.bed', emit: bed
    path 'versions.yml', emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    apt-get update && apt-get install -y sqlite3

    sqlite3 \
        $db \
        -separator \$'\t' \
        -header \
        "SELECT chrom, \
                start - 1 AS chromStart, \
                end AS chromEnd, \
                name, \
                '.' AS score, \
                CASE strand WHEN 1 THEN '+' WHEN -1 THEN '-' END AS strand \
                FROM Genes" \
        > genes.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sqlite: \$(sqlite3 --version | sed -e "s/SQLite version //g" | cut -d' ' -f1)
    END_VERSIONS
    """

}