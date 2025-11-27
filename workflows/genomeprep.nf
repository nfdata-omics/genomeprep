/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { HANDLE_README} from '../modules/local/handle_readme/main.nf'
include { COUNT_CHROMOSOMES_SIZES } from '../modules/local/count_chromosomes_sizes/main.nf'
include { CELLRANGER_MKGTF } from '../modules/nf-core/cellranger/mkgtf/main.nf'
include { CELLRANGER_MKREF } from '../modules/nf-core/cellranger/mkref/main'
include { CELLRANGERATAC_MKREF } from '../modules/nf-core/cellrangeratac/mkref/main'
include { CELLRANGER_MKVDJREF } from '../modules/nf-core/cellranger/mkvdjref/main'
include { SPACERANGER_MKREF } from '../modules/nf-core/spaceranger/mkref/main'
include { BOWTIE2_BUILD } from '../modules/nf-core/bowtie2/build/main'
include { BWA_INDEX } from '../modules/nf-core/bwa/index/main.nf'
include { SAMTOOLS_FAIDX } from '../modules/nf-core/samtools/faidx/main.nf'
include { STAR_GENOMEGENERATE } from '../modules/nf-core/star/genomegenerate/main'
include { GATK4_CREATESEQUENCEDICTIONARY } from '../modules/nf-core/gatk4/createsequencedictionary/main.nf'
include { BISMARK_GENOMEPREPARATION } from '../modules/nf-core/bismark/genomepreparation/main'
include { RSEM_PREPAREREFERENCE } from '../modules/nf-core/rsem/preparereference/main'
include { SALMON_INDEX } from '../modules/nf-core/salmon/index/main.nf'
include { MD5SUM } from '../modules/nf-core/md5sum/main'

include { CREATE_GENES_DB} from '../modules/local/create_genes_db/main.nf'
include { CREATE_BED_FILES } from '../modules/local/create_bed_files/main.nf'
include { CREATE_GENOMES_CONFIG } from '../modules/local/create_genomes_config/main.nf'

include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_genomeprep_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow GENOMEPREP {

    take:
        fasta // channel: fasta read in from --fasta
        gtf   // channel: gtf read in from --gtf
        transcripts_fasta // channel: transcripts fasta read in from --transcripts_fasta
        genome_version_name // string: genome version name read in from --genome_version_name
        organism // string: organism name read in from --organism
        current_config_file // string: path to the current config file
        fasta_readme // channel: fasta readme read in from --fasta_readme
        gtf_readme // channel: gtf readme read in from --gtf_readme
        vdj_fasta // channel: vdj_fasta read in from --vdj_fasta
        non_nuclear_contigs // channel: non-nuclear contigs to be excluded from ATAC reference generation (e.g.: --non_nuclear_contigs "chrM,chrY")
        transcription_factors // channel: transcription factors read in from --transcription_factors (e.g.: --transcription_factors "motifs.pfm")

    main:

        ch_versions = channel.empty()

        //
        // Create README for the Genome Version based on FASTA and GTF READMEs
        HANDLE_README(fasta_readme,
                      gtf_readme,
                      genome_version_name,
                      current_config_file)

        //
        // Count chromosomes sizes
        //
        COUNT_CHROMOSOMES_SIZES(fasta)

        //
        // Run Bowtie2 indexing
        //
        BOWTIE2_BUILD(fasta)

        //
        // Run BWA indexing
        //
        BWA_INDEX(fasta)

        //
        // Run samtools indexing
        //
        SAMTOOLS_FAIDX(fasta,
                       tuple("", file("no_fai", checkIfExists: false)),
                       Channel.from(false))

        //
        // Run STAR indexing
        //
        STAR_GENOMEGENERATE(fasta,
                            gtf)

        //
        // Create sequence dictionary with GATK4
        //
        GATK4_CREATESEQUENCEDICTIONARY(fasta)

        //
        // Run Bismark indexing
        //
        BISMARK_GENOMEPREPARATION(fasta)

        //
        // Create a GTF channel to handle missing files
        //
        ch_gtf_valid = gtf.filter { meta, file -> file.name != "no_gtf" }

        //
        // Run RSEM indexing
        //
        RSEM_PREPAREREFERENCE(
            fasta.map { it[1] },
            ch_gtf_valid.map { it[1] }
        )

        // Channel to handle RSEM output
        ch_rsem = RSEM_PREPAREREFERENCE.out.index.ifEmpty {
            file("no_rsem", checkIfExists: false)
        }

        //
        // Run Salmon indexing if transcripts_fasta is provided
        //
        SALMON_INDEX(
            fasta.map { it[1] },
            transcripts_fasta
        )

        /// Channel to handle Salmon output
        ch_salmon = SALMON_INDEX.out.index.ifEmpty {
            file("no_salmon", checkIfExists: false)
        }

        //
        // Create genes database
        //
        CREATE_GENES_DB(
            ch_gtf_valid.map { it[1] }
        )

        // Channel to handle CREATE_GENES_DB output
        ch_db = CREATE_GENES_DB.out.db.ifEmpty {
            file("no_genes_db", checkIfExists: false)
        }

        //
        // Create BED files from DB
        //
        CREATE_BED_FILES(
            CREATE_GENES_DB.out.db
        )

        // Channel to handle CREATE_BED_FILES output
        ch_bed = CREATE_BED_FILES.out.bed.ifEmpty {
            file("no_bed", checkIfExists: false)
        }

    // Default placeholders for optional references when running with the `test` profile
    // These ensure downstream code can always reference the channels even if
    // the mkref processes are skipped in the test profile.
    ch_cellranger = Channel.from(file("no_cellranger", checkIfExists: false))
    ch_vdj = Channel.from(file("no_cellranger_vdj", checkIfExists: false))
    ch_spaceranger = Channel.from(file("no_spaceranger", checkIfExists: false))
    ch_atac = Channel.from(file("no_atac", checkIfExists: false))

    // Default empty version channels for optional processes (will be overridden
    // if the corresponding mkref process is invoked)
    ch_mkref_versions = Channel.empty()
    ch_mkvdjref_versions = Channel.empty()
    ch_spaceranger_versions = Channel.empty()
    ch_atac_mkref_versions = Channel.empty()

        //
        // Filter GTF using Cell Ranger mkgtf
        //
        CELLRANGER_MKGTF(
            ch_gtf_valid.map { it[1] }
        )

        //
        // Create Cell Ranger reference
        //
    if (!workflow.profile?.contains('test')) {
            CELLRANGER_MKREF(
                fasta.map { it[1] },
                CELLRANGER_MKGTF.out.gtf,
                genome_version_name
            )

            // Channel to handle CELLRANGER_MKREF output
            ch_cellranger = CELLRANGER_MKREF.out.reference.ifEmpty {
                file("no_cellranger", checkIfExists: false)
            }

            // versions channel for CELLRANGER_MKREF
            ch_mkref_versions = CELLRANGER_MKREF.out.versions
        }

    //
    // Create Cell Ranger VDJ reference
    //
    if (!workflow.profile?.contains('test')) {
            CELLRANGER_MKVDJREF(
                fasta.map { it[1] },
                CELLRANGER_MKGTF.out.gtf,
                vdj_fasta,
                genome_version_name
            )

            // Channel to handle CELLRANGER_MKVDJREF output
            ch_vdj = CELLRANGER_MKVDJREF.out.reference.ifEmpty {
                file("no_cellranger_vdj", checkIfExists: false)
            }

            // versions channel for CELLRANGER_MKVDJREF
            ch_mkvdjref_versions = CELLRANGER_MKVDJREF.out.versions
        }

        //
        // Create Spacer Ranger reference
        //
    if (!workflow.profile?.contains('test')) {
            SPACERANGER_MKREF(
                fasta.map { it[1] },
                CELLRANGER_MKGTF.out.gtf,
                genome_version_name
            )

            // Channel to handle SPACERANGER_MKREF output
            ch_spaceranger = SPACERANGER_MKREF.out.reference.ifEmpty {
                file("no_spaceranger", checkIfExists: false)
            }

            // versions channel for SPACERANGER_MKREF
            ch_spaceranger_versions = SPACERANGER_MKREF.out.versions
        }

        //
        // Create Cell Ranger ATAC reference
        //
    if (!workflow.profile?.contains('test')) {
            CELLRANGERATAC_MKREF(
                fasta.map { it[1] },
                CELLRANGER_MKGTF.out.gtf,
                organism,
                genome_version_name,
                non_nuclear_contigs,
                transcription_factors,
                genome_version_name
            )

            // Channel to handle CELLRANGERATAC_MKREF output
            ch_atac = CELLRANGERATAC_MKREF.out.reference.ifEmpty {
                file("no_atac", checkIfExists: false)
            }

            // versions channel for CELLRANGERATAC_MKREF
            ch_atac_mkref_versions = CELLRANGERATAC_MKREF.out.versions
        }

        // Create genomes.config file
        CREATE_GENOMES_CONFIG(
            genome_version_name,
            current_config_file,
            fasta.collect { it[1] },
            BOWTIE2_BUILD.out.index.collect { it[1] },
            BWA_INDEX.out.index.collect { it[1] },
            GATK4_CREATESEQUENCEDICTIONARY.out.dict.collect { it[1] },
            SAMTOOLS_FAIDX.out.fai.collect { it[1] },
            STAR_GENOMEGENERATE.out.index.collect { it[1] },
            BISMARK_GENOMEPREPARATION.out.index.collect { it[1] },
            COUNT_CHROMOSOMES_SIZES.out.chromosomes_sizes,
            HANDLE_README.out.readme,
            ch_rsem,
            ch_salmon,
            ch_db,
            ch_bed,
            gtf.collect { it[1] },
            ch_cellranger,
            ch_atac,
            ch_vdj,
            ch_spaceranger
        )

        //
        // Mix output files for MD5SUM
        //
        Channel.empty()
            .mix(
                HANDLE_README.out.readme
                    .map { file -> tuple([id: file.baseName], file) },
                COUNT_CHROMOSOMES_SIZES.out.chromosomes_sizes
                    .map { file -> tuple([id: file.baseName], file) },
                BOWTIE2_BUILD.out.index
                    .map { meta, file -> tuple([id: file.baseName], file) },
                BWA_INDEX.out.index
                    .map { meta, file -> tuple([id: file.baseName], file) },
                SAMTOOLS_FAIDX.out.fai
                    .map { meta, file -> tuple([id: file.baseName], file) },
                STAR_GENOMEGENERATE.out.index
                    .map { meta, file -> tuple([id: file.baseName], file) },
                GATK4_CREATESEQUENCEDICTIONARY.out.dict
                    .map { meta, file -> tuple([id: file.baseName], file) },
                BISMARK_GENOMEPREPARATION.out.index
                    .map { meta, file -> tuple([id: file.baseName], file) },
                CREATE_GENOMES_CONFIG.out.config
                    .map { file -> tuple([id: file.baseName], file) },
                RSEM_PREPAREREFERENCE.out.index
                    .ifEmpty([])
                    .filter { it != [] }
                    .map { file -> tuple([id: file.baseName], file) },
                SALMON_INDEX.out.index
                    .ifEmpty([])
                    .filter { it != [] }
                    .map { file -> tuple([id: file.baseName], file) },
                CREATE_BED_FILES.out.bed
                    .ifEmpty([])
                    .filter { it != [] }
                    .map { file -> tuple([id: file.baseName], file) },
                CREATE_GENES_DB.out.db
                    .ifEmpty([])
                    .filter { it != [] }
                    .map { file -> tuple([id: file.baseName], file) },
                ch_cellranger
                    .ifEmpty([])
                    .filter { it != [] }
                    .map { file -> tuple([id: file.baseName], file) },
                ch_atac
                    .ifEmpty([])
                    .filter { it != [] }
                    .map { file -> tuple([id: file.baseName], file) },
                ch_vdj
                    .ifEmpty([])
                    .filter { it != [] }
                    .map { file -> tuple([id: file.baseName], file) },
                ch_spaceranger
                    .ifEmpty([])
                    .filter { it != [] }
                    .map { file -> tuple([id: file.baseName], file) },
            )
            .set { ch_for_md5 }

        MD5SUM(ch_for_md5, false)

        //
        // Retrieve versions.yml output of each process
        //
        ch_chromosomes_sizes_versions = COUNT_CHROMOSOMES_SIZES.out.versions
        ch_bowtie2_versions = BOWTIE2_BUILD.out.versions
        ch_bwa_versions = BWA_INDEX.out.versions
        ch_samtools_versions = SAMTOOLS_FAIDX.out.versions
        ch_star_versions = STAR_GENOMEGENERATE.out.versions
        ch_gatk4_versions = GATK4_CREATESEQUENCEDICTIONARY.out.versions
        ch_bismark_versions = BISMARK_GENOMEPREPARATION.out.versions
        ch_rsem_versions = RSEM_PREPAREREFERENCE.out.versions
        ch_salmon_versions = SALMON_INDEX.out.versions
        ch_bed_versions = CREATE_BED_FILES.out.versions
        ch_db_versions = CREATE_GENES_DB.out.versions
        // ch_*_versions are set to defaults above; they will be overridden
        // inside the corresponding if-blocks when the mkref processes run.
        ch_mkref_versions = ch_mkref_versions
        ch_mkvdjref_versions = ch_mkvdjref_versions
        ch_spaceranger_versions = ch_spaceranger_versions
        ch_atac_mkref_versions = ch_atac_mkref_versions
        ch_config_versions = CREATE_GENOMES_CONFIG.out.versions
        ch_md5sum_versions = MD5SUM.out.versions

        //
        // Add software versions to `ch_versions`
        //

        ch_versions = ch_versions
            .mix(
                ch_chromosomes_sizes_versions,
                ch_bowtie2_versions,
                ch_bwa_versions,
                ch_samtools_versions,
                ch_star_versions,
                ch_gatk4_versions,
                ch_bismark_versions,
                ch_rsem_versions,
                ch_salmon_versions,
                ch_bed_versions,
                ch_db_versions,
                ch_mkref_versions,
                ch_mkvdjref_versions,
                ch_spaceranger_versions,
                ch_atac_mkref_versions,
                ch_config_versions,
                ch_md5sum_versions
            ).flatten()

    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'genomeprep_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    emit:
        versions       = ch_versions
        bowtie2_build = BOWTIE2_BUILD.out.index
        bwa_index = BWA_INDEX.out.index
        samtools_index = SAMTOOLS_FAIDX.out.fai
        star_index = STAR_GENOMEGENERATE.out.index
        gatk4_dict = GATK4_CREATESEQUENCEDICTIONARY.out.dict
        genomes_config = CREATE_GENOMES_CONFIG.out.config

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
