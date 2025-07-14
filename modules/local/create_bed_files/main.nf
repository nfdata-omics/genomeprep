process CREATE_BED_FILES {
    
    container 'docker.io/ubuntu:22.04'
    containerOptions '--user root'

    tag "$db"

    input:
    path db

    output:
    path 'bed', emit: bed
    path 'versions.yml', emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    apt-get update && apt-get install -y sqlite3

    mkdir -p bed

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
        > bed/genes.bed

    sqlite3 \
        $db \
        -separator \$'\t' \
        -header \
        "SELECT chrom, \
                CASE \
                    WHEN strand = 1 THEN MAX(tss - 2000 - 1, 0) \
                    WHEN strand = -1 THEN tss + 1 \
                END AS chromStart, \
                CASE \
                    WHEN strand = 1 THEN tss - 1 \
                    WHEN strand = -1 THEN tss + 2001 \
                END AS chromEnd, \
                name, \
                '.' AS score, \
                CASE strand WHEN 1 THEN '+' WHEN -1 THEN '-' END AS strand \
                FROM Genes" \
        > bed/promoters.bed
                

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sqlite: \$(sqlite3 --version | sed -e "s/SQLite version //g" | cut -d' ' -f1)
    END_VERSIONS
    """

}