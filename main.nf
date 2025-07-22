#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/genomeprep
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/genomeprep
    Website: https://nf-co.re/genomeprep
    Slack  : https://nfcore.slack.com/channels/genomeprep
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GENOMEPREP  } from './workflows/genomeprep'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_genomeprep_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_genomeprep_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_GENOMEPREP {

    take:
    fasta // channel: fasta read in from --fasta
    gtf   // channel: gtf read in from --gtf
    transcripts_fasta // channel: transcripts fasta read in from --transcripts_fasta
    genome_version_name // string: genome version name read in from --genome_version_name
    organism // string: organism name read in from --organism
    current_config_file
    fasta_readme // channel: fasta readme read in from --fasta_readme
    gtf_readme // channel: gtf readme read in from --gtf_readme
    vdj_fasta // channel: vdj fasta read in from --vdj_fasta
    non_nuclear_contigs // channel: non-nuclear contigs to be excluded from ATAC reference generation (e.g.: --non_nuclear_contigs "chrM,chrY")
    transcription_factors // channel: transcription factors read in from --transcription_factors (e.g.: --transcription_factors "motifs.pfm")

    main:

    //
    // WORKFLOW: Run pipeline
    //
    GENOMEPREP (
        fasta, gtf, transcripts_fasta, genome_version_name, organism, current_config_file, fasta_readme, gtf_readme, vdj_fasta, non_nuclear_contigs, transcription_factors
    )
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.fasta,
        params.gtf,
        params.transcripts_fasta,
        params.genome_version_name,
        params.organism,
        params.current_config_file,
        params.fasta_readme,
        params.gtf_readme,
        params.vdj_fasta,
        params.non_nuclear_contigs,
        params.transcription_factors,
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_GENOMEPREP (
        PIPELINE_INITIALISATION.out.fasta,
        PIPELINE_INITIALISATION.out.gtf,
        PIPELINE_INITIALISATION.out.transcripts_fasta,
        PIPELINE_INITIALISATION.out.genome_version_name,
        PIPELINE_INITIALISATION.out.organism,
        PIPELINE_INITIALISATION.out.current_config_file,
        PIPELINE_INITIALISATION.out.fasta_readme,
        PIPELINE_INITIALISATION.out.gtf_readme,
        PIPELINE_INITIALISATION.out.vdj_fasta,
        PIPELINE_INITIALISATION.out.non_nuclear_contigs,
        PIPELINE_INITIALISATION.out.transcription_factors
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
    )
}

workflow.onComplete {
    def outdir = params.outdir
    def cmd = """
        find ${outdir} -maxdepth 3 -type f -not -path "${outdir}/pipeline_info/*" -exec chmod 444 {} \\;
    """

    def proc = ["bash", "-c", cmd].execute()
    proc.in.eachLine { println "[chmod] $it" }
    proc.waitFor()

    if (proc.exitValue() == 0) {
        println "[onComplete] File permissions changed successfully."
    } else {
        println "[onComplete] Failed to change file permissions."
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
