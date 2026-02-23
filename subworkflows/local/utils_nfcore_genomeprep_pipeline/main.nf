//
// Subworkflow with functionality specific to the nfdata-omics/genomeprep pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { samplesheetToList         } from 'plugin/nf-schema'
include { paramsHelp                } from 'plugin/nf-schema'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    base_dir          //  string: The base directory for the config
    fasta             //  string: Path to input samplesheet
    gtf              //  string: Path to GTF file
    transcripts_fasta //  string: Path to transcripts FASTA file
    genome_version_name // string: Name of the genome version
    source           //  string: Source of the genome (e.g., Ensembl, UCSC, NCBI)
    taxid        //  string: NCBI Taxonomy ID of the organism
    organism          //  string: Name of the organism
    current_config_file //  string: Path to the current config file
    fasta_readme      //  string: Path to FASTA readme file
    gtf_readme        //  string: Path to GTF readme file
    vdj_fasta        //  string: Path to VDJ fasta file
    non_nuclear_contigs //  string: Comma-separated list of non-nuclear contigs to be excluded from ATAC reference generation (e.g.: --non_nuclear_contigs "chrM,chrY")
    transcription_factors //  string: Comma-separated list of transcription factors
    help              // boolean: Display help message and exit
    help_full         // boolean: Show the full help message
    show_hidden       // boolean: Show hidden parameters in the help message

    main:

    ch_versions = channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"

    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        "",
        "",
        command
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Create channel from base directory provided through params.base_dir
    //
    ch_base_dir = base_dir ?
                Channel.value(base_dir) :
                Channel.value("no_provided_base_dir")
    //
    // Create channel from fasta file provided through params.fasta
    //
    ch_fasta = Channel.fromPath(fasta).map { file ->
            def meta = file.baseName
            tuple(meta, file)
    }

    //
    // Create channel from gtf file provided through params.gtf
    //
    ch_gtf = gtf ?
        Channel.fromPath(gtf).map { file ->
            def meta = file.baseName
            tuple(meta, file)
        } :
        Channel.value(tuple("no_gtf", file('no_gtf')))

    //
    // Create channel from transcripts fasta file provided through params.transcripts_fasta
    //
    ch_transcripts_fasta = transcripts_fasta ?
        Channel.fromPath(transcripts_fasta) :
        Channel.empty()

    //
    // Create channel from genome version name provided through params.genome_version_name
    //
    ch_genome_version_name = Channel.value(genome_version_name)

    //
    // Create channel from source provided through params.source
    //
    ch_source = Channel.value(source)

    //
    // Create channel from taxid provided through params.taxid
    //
    ch_taxid = Channel.value(taxid.toString())

    //
    // Create channel from organism name provided through params.organism
    //
    ch_organism = Channel.value(organism)

    //
    // Create channel from current config file provided through params.current_config_file
    //
    ch_current_config_file = current_config_file ?
        Channel.fromPath(current_config_file) :
        Channel.from(file('no_current_config_file', checkIfExists: false))

    //
    // Create channel from fasta readme file provided through params.fasta_readme
    //
    ch_fasta_readme = Channel.from(file(fasta_readme))

    //
    // Create channel from gtf readme file provided through params.gtf_readme
    //
    ch_gtf_readme = gtf_readme ?
        Channel.from(gtf_readme) :
        Channel.from(file("no_gtf_readme", checkIfExists: false))

    //
    // Create channel from vdj fasta file provided through params.vdj_fasta
    //
    ch_vdj_fasta = vdj_fasta ?
        Channel.fromPath(vdj_fasta) :
        file('no_vdj_fasta', checkIfExists: false)

    //
    // Create channel for non-nuclear contigs
    //
    ch_non_nuclear_contigs = Channel.value(
        non_nuclear_contigs ? non_nuclear_contigs.split(',') : []
    )


    //
    // Create channel for transcription factors
    //
    ch_transcription_factors = transcription_factors ?
        Channel.value(transcription_factors) :
        Channel.from(file('no_motifs', checkIfExists: false))

    emit:
    base_dir = ch_base_dir
    fasta = ch_fasta
    gtf = ch_gtf
    transcripts_fasta = ch_transcripts_fasta
    genome_version_name = ch_genome_version_name
    source = ch_source
    taxid = ch_taxid
    organism = ch_organism
    current_config_file = ch_current_config_file
    fasta_readme = ch_fasta_readme
    gtf_readme = ch_gtf_readme
    vdj_fasta = ch_vdj_fasta
    non_nuclear_contigs = ch_non_nuclear_contigs
    transcription_factors = ch_transcription_factors
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        //  string: hook URL for notifications

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        try {
            def publish_outdir
            try {
                // if `outdir` is defined this will return it, otherwise will throw MissingPropertyException
                publish_outdir = outdir ?: params?.outdir
            } catch(Exception _ignored) {
                publish_outdir = params?.outdir ?: null
            }

            if (!publish_outdir) {
                log.warn "onComplete: output directory not set, skipping permission changes"
                return
            }

            def root = new File(publish_outdir)
            if (!root.exists() || !root.isDirectory()) {
                log.warn "onComplete: publish_outdir does not exist or is not a directory: ${publish_outdir}"
                return
            }

            root.eachFileRecurse { f ->
                try {
                    def rel = root.toPath().relativize(f.toPath()).toString()
                    if (rel == "") return
                    def depth = rel.split(/[\\/]/).size()
                    if (depth > 3) return
                    if (rel.startsWith("pipeline_info${File.separator}") || rel == 'pipeline_info') return
                    if (f.isFile()) {
                        f.setWritable(false, false)
                        println "[chmod] ${f}"
                    }
                } catch(Exception e) {
                    log.warn "onComplete: failed to change permissions for ${f}: ${e.message}"
                }
            }

            println "[onComplete] File permissions processed."
        } catch(Exception e) {
            log.error "onComplete handler failed: ${e.message}", e
        }
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    def (metas, fastqs) = input[1..2]

    // Check that multiple runs of the same sample are of the same datatype i.e. single-end / paired-end
    def endedness_ok = metas.collect{ meta -> meta.single_end }.unique().size == 1
    if (!endedness_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be of the same datatype i.e. single-end or paired-end: ${metas[0].id}")
    }

    return [ metas[0], fastqs ]
}
//
// Generate methods description for MultiQC
//
def toolCitationText() {
    // TODO nf-core: Optionally add in-text citation tools to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "Tool (Foo et al. 2023)" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def citation_text = [
            "Tools used in the workflow included:",
            "."
        ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    // TODO nf-core: Optionally add bibliographic entries to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "<li>Author (2023) Pub name, Journal, DOI</li>" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def reference_text = [
        ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familiar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    if (meta.manifest_map.doi) {
        // Using a loop to handle multiple DOIs
        // Removing `https://doi.org/` to handle pipelines using DOIs vs DOI resolvers
        // Removing ` ` since the manifest.doi is a string and not a proper list
        def temp_doi_ref = ""
        def manifest_doi = meta.manifest_map.doi.tokenize(",")
        manifest_doi.each { doi_ref ->
            temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        }
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    } else meta["doi_text"] = ""
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Tool references
    meta["tool_citations"] = ""
    meta["tool_bibliography"] = ""

    // TODO nf-core: Only uncomment below if logic in toolCitationText/toolBibliographyText has been filled!
    // meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    // meta["tool_bibliography"] = toolBibliographyText()


    def methods_text = mqc_methods_yaml.text

    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}
