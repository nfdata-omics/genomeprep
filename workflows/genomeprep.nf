/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { COUNT_CHROMOSOMES_SIZES } from '../modules/local/count_chromosomes_sizes/main.nf'
include { BOWTIE2_BUILD } from '../modules/nf-core/bowtie2/build/main'
include { BWA_INDEX } from '../modules/nf-core/bwa/index/main.nf'
include { SAMTOOLS_FAIDX } from '../modules/nf-core/samtools/faidx/main.nf'
include { STAR_GENOMEGENERATE } from '../modules/nf-core/star/genomegenerate/main'
include { GATK4_CREATESEQUENCEDICTIONARY } from '../modules/nf-core/gatk4/createsequencedictionary/main.nf'
include { BISMARK_GENOMEPREPARATION } from '../modules/nf-core/bismark/genomepreparation/main'
include { RSEM_PREPAREREFERENCE } from '../modules/nf-core/rsem/preparereference/main' 
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

    main:
        ch_versions = Channel.empty()

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
        // Run RSEM indexing
        //
        ch_gtf_valid = gtf.filter { meta, file -> file.name != "no_gtf" }

        RSEM_PREPAREREFERENCE(
            fasta.map { it[1] },
            ch_gtf_valid.map { it[1] }
        )

        //
        // Create channel to handle RSEM output
        //
        ch_rsem = RSEM_PREPAREREFERENCE.out.index.ifEmpty {
            file("no_rsem", checkIfExists: false)
        }

        //
        // Create genes database
        //
        CREATE_GENES_DB(
            ch_gtf_valid.map { it[1] }
        )

        ch_db = CREATE_GENES_DB.out.db.ifEmpty {
            file("no_genes_db", checkIfExists: false)
        }

        //
        // Create BED files from DB
        //
        CREATE_BED_FILES(
            CREATE_GENES_DB.out.db
        )

        ch_bed = CREATE_BED_FILES.out.bed.ifEmpty {
            file("no_bed", checkIfExists: false)
        }

        // Create genomes.config file
        CREATE_GENOMES_CONFIG(
            params.genome_version_name,
            params.current_config_file,
            fasta.collect { it[1] },
            BOWTIE2_BUILD.out.index.collect { it[1] },
            BWA_INDEX.out.index.collect { it[1] },
            GATK4_CREATESEQUENCEDICTIONARY.out.dict.collect { it[1] },
            SAMTOOLS_FAIDX.out.fai.collect { it[1] },
            STAR_GENOMEGENERATE.out.index.collect { it[1] },
            BISMARK_GENOMEPREPARATION.out.index.collect { it[1] },
            ch_rsem,
            ch_db,
            ch_bed,
            gtf.collect { it[1] }
        )

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
        ch_bed_versions = CREATE_BED_FILES.out.versions
        ch_db_versions = CREATE_GENES_DB.out.versions
        ch_config_versions = CREATE_GENOMES_CONFIG.out.versions

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
                ch_bed_versions,
                ch_db_versions,
                ch_config_versions
            ).flatten()

        //
        // Collate and save software versions
        //
        softwareVersionsToYAML(ch_versions)
            .collectFile(
                storeDir: "${params.outdir}/pipeline_info",
                name: 'nf_core_'  +  'genomeprep_software_'  + 'versions.yml',
                sort: true,
                newLine: true
            ).set { ch_collated_versions }

    emit:
        versions       = ch_versions                 // channel: [ path(versions.yml) ]
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
