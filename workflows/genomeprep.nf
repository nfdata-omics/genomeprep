/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { BOWTIE2_BUILD } from '../modules/nf-core/bowtie2/build/main'
include { BWA_INDEX } from '../modules/nf-core/bwa/index/main.nf'
include { SAMTOOLS_FAIDX } from '../modules/nf-core/samtools/faidx/main.nf'
include { STAR_GENOMEGENERATE } from '../modules/nf-core/star/genomegenerate/main'
include { GATK4_CREATESEQUENCEDICTIONARY } from '../modules/nf-core/gatk4/createsequencedictionary/main.nf'
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
        STAR_GENOMEGENERATE(fasta, gtf)

        //
        // Create sequence dictionary with GATK4
        //
        GATK4_CREATESEQUENCEDICTIONARY(fasta)

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
            gtf.collect { it[1] }
        )

        //
        // Retrieve versions.yml output of each process 
        //
        ch_bowtie2_versions = BOWTIE2_BUILD.out.versions
        ch_bwa_versions = BWA_INDEX.out.versions
        ch_samtools_versions = SAMTOOLS_FAIDX.out.versions
        ch_star_versions = STAR_GENOMEGENERATE.out.versions
        ch_gatk4 = GATK4_CREATESEQUENCEDICTIONARY.out.versions

        //
        // Add software versions to `ch_versions`
        //
        ch_versions = ch_versions
            .mix(
                ch_bowtie2_versions,
                ch_bwa_versions,
                ch_samtools_versions,
                ch_star_versions,
                ch_gatk4
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
