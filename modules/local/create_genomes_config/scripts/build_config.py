import argparse

from core.genome_config import Genome, GenomeConfig
from utils.config_utils import genome_config_to_nf_params, write_to_file, read_config_file

import logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

# Add parameters for genome configuration
parser = argparse.ArgumentParser(description="Build genome configuration for nf-core genomeprep")
parser.add_argument(
    "--genomeVersionName",
    type=str,
    required=True,
    help="Name of the genome version to be configured (e.g., hg38, mm10)",
)
parser.add_argument(
    "--currentConfigFile",
    type=str,
    required=False,
    help="Path to the current configuration file (optional, for updating existing configurations)",
)
parser.add_argument(
    "--fasta",
    type=str,
    required=True,
    help="Path to the FASTA file for the genome",
)
parser.add_argument(
    "--bwa",
    type=str,
    required=True,
    help="Path to the BWA index file for the genome",
)
parser.add_argument(
    "--bowtie2",
    type=str,
    required=True,
    help="Path to the Bowtie2 index file for the genome",
)
parser.add_argument(
    "--gatk",
    type=str,
    required=True,
    help="Path to the GATK index file for the genome",
)
parser.add_argument(
    "--samtools",
    type=str,
    required=True,
    help="Path to the Samtools index file for the genome",
)
parser.add_argument(
    "--star",
    type=str,
    required=False,
    help="Path to the STAR index file for the genome (optional)",
)
parser.add_argument(
    "--bismark",
    type=str,
    required=False,
    help="Path to the Bismark index file for the genome (optional)",
)
parser.add_argument(
    "--gtf",
    type=str,
    required=False,
    help="Path to the GTF file for the genome (optional)",
)
parser.add_argument(
    "--bed12",
    type=str,
    required=False,
    help="Path to the BED12 file for the genome (optional)",
)
parser.add_argument(
    "--readme",
    type=str,
    required=False,
    help="Path to the README file for the genome (optional)",
)
parser.add_argument(
    "--mito_name",
    type=str,
    required=False,
    help="Name of the mitochondrial genome (optional)",
)
parser.add_argument(
    "--macs_gsize",
    type=str,
    required=False,
    help="Genome size for MACS (optional)",
)
parser.add_argument(
    "--blacklist",
    type=str,
    required=False,
    help="Path to the blacklist file for the genome (optional)",
)
parser.add_argument(
    "--outputFile",
    type=str,
    required=False,
    help="Path to the output file where the genome configuration will be written (optional)",
)

# Parse arguments
args = parser.parse_args()

# Log the configuration details in a single logging statement
logging.info(
    f"Building genome configuration for {args.genomeVersionName} with parameters: \n"
    f"Current config file: {args.currentConfigFile if args.currentConfigFile else 'None'}, \n"
    f"FASTA: {args.fasta}, \n"
    f"BWA: {args.bwa}, \n"
    f"Bowtie2: {args.bowtie2}, \n"
    f"GATK: {args.gatk}, \n"
    f"Samtools: {args.samtools}, \n"
    f"STAR: {args.star if args.star else 'None'}, \n"
    f"Bismark: {args.bismark if args.bismark else 'None'}, \n"
    f"GTF: {args.gtf if args.gtf else 'None'}, \n"
    f"BED12: {args.bed12 if args.bed12 else 'None'}, \n"
    f"README: {args.readme if args.readme else 'None'}, \n"
    f"Mitochondrial name: {args.mito_name if args.mito_name else 'None'}, \n"
    f"MACS genome size: {args.macs_gsize if args.macs_gsize else 'None'}, \n"
    f"Blacklist: {args.blacklist if args.blacklist else 'None'}"
)

# Create instance of Genome with provided parameters
genome_version = {
    "fasta": args.fasta,
    "bwa": args.bwa,
    "bowtie2": args.bowtie2,
    "gatk": args.gatk,
    "samtools": args.samtools,
    "star": args.star,
    "bismark": args.bismark,
    "gtf": args.gtf,
    "bed12": args.bed12,
    "readme": args.readme,
    "mito_name": args.mito_name,
    "macs_gsize": args.macs_gsize,
    "blacklist": args.blacklist,
}
genome = Genome(**genome_version)

# Create GenomeConfig and add the genome
if args.currentConfigFile == None:
    config = GenomeConfig()
else:
    try:
        config = read_config_file(args.currentConfigFile)
    except FileNotFoundError:
        logging.error(f"Configuration file '{args.currentConfigFile}' does not exist.")
        raise
    except Exception as e:
        logging.error(f"Failed to read configuration file '{args.currentConfigFile}': {e}")
        raise

try:
    config.add_genome(args.genomeVersionName, genome)
except:
    logging.error(f"Failed to add genome '{args.genomeVersionName}' to the configuration.")
    raise

# Convert GenomeConfig to nextflow parameters format
nf_params = genome_config_to_nf_params(config)

# Write nextflow parameters to file
logging.info("Writing genome information into config file...")
if args.outputFile:
    output_file = args.outputFile
else:
    output_file = "genomes.config"
write_to_file(nf_params, output_file)

logging.info("Done.")