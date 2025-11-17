process COUNT_CHROMOSOMES_SIZES {

    publishDir "${params.outdir}/chromosomes_sizes/", mode: 'copy'

    tag "$fasta"

    container 'quay.io/biocontainers/biopython:1.79'

    input:
    tuple val(meta), path(fasta)

    output:
    path "versions.yml", emit: versions
    path "chromosomes_sizes.tsv", emit: chromosomes_sizes

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    python3 -c "
    from Bio import SeqIO
    import sys

    handle = open('${fasta}', 'r')
    sequence_lengths = {}
    SeqRecords = SeqIO.parse(handle, 'fasta')
    for record in SeqRecords:
        length = len(record.seq)
        sequence_lengths[record.id] = length

    with open('chromosomes_sizes.tsv', 'w') as out_file:
        out_file.write('chromosome\\tsize\\n')
        for chromosome, size in sequence_lengths.items():
            out_file.write(f'{chromosome}\\t{size}\\n')
    handle.close()
    "

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | cut -d' ' -f2)
        biopython: \$(python3 -c "import Bio; print(Bio.__version__)" | cut -d' ' -f1)
    END_VERSIONS
    """
}
