process CREATE_BED_FILES {

    publishDir "${params.outdir}/bed_files/", mode: 'copy'

    container 'docker.io/nfdata/genes-db:v1.1.0'

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
    #!/bin/bash
    set -euo pipefail

    mkdir -p bed

    python3.11 -c "
import sqlite3

conn = sqlite3.connect('$db')
cursor = conn.cursor()

genes_query = '''
SELECT chrom,
       start - 1 AS chromStart,
       end AS chromEnd,
       name,
       '.' AS score,
       CASE strand WHEN 1 THEN '+' WHEN -1 THEN '-' END AS strand
FROM Genes
'''

promoters_query = '''
SELECT chrom,
       CASE
           WHEN strand = 1 THEN MAX(tss - 2000 - 1, 0)
           WHEN strand = -1 THEN tss + 1
       END AS chromStart,
       CASE
           WHEN strand = 1 THEN tss - 1
           WHEN strand = -1 THEN tss + 2001
       END AS chromEnd,
       name,
       '.' AS score,
       CASE strand WHEN 1 THEN '+' WHEN -1 THEN '-' END AS strand
FROM Genes
'''

with open('bed/genes.bed', 'w') as f:
    f.write('chrom\\tchromStart\\tchromEnd\\tname\\tscore\\tstrand\\n')
    for row in cursor.execute(genes_query):
        f.write('\\t'.join(map(str, row)) + '\\n')

with open('bed/promoters.bed', 'w') as f:
    f.write('chrom\\tchromStart\\tchromEnd\\tname\\tscore\\tstrand\\n')
    for row in cursor.execute(promoters_query):
        f.write('\\t'.join(map(str, row)) + '\\n')

conn.close()
"

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    python: \$(python3.11 --version | cut -d' ' -f2)
END_VERSIONS
    """
}
