import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from core.genome_config import Genome, GenomeConfig

def test_genome_creation_required_fields():

    genome_version = {
        "fasta": "/path/to/fasta/file",
        "bwa": "/path/to/bwa/index/file",
        "bowtie2": "/path/to/bowtie2/index/file",
        "gatk": "/path/to/gatk/index/file",
        "samtools": "/path/to/samtools/index/file"
    }

    genome_instance = Genome(**genome_version)

    assert genome_instance.fasta == genome_version['fasta']
    assert genome_instance.bwa == genome_version['bwa']
    assert genome_instance.bowtie2 == genome_version['bowtie2']
    assert genome_instance.gatk == genome_version['gatk']
    assert genome_instance.samtools == genome_version['samtools']

def test_genome_creation_optional_fields():

    genome_version = {
        "fasta": "/path/to/fasta/file",
        "bwa": "/path/to/bwa/index/file",
        "bowtie2": "/path/to/bowtie2/index/file",
        "gatk": "/path/to/gatk/index/file",
        "samtools": "/path/to/samtools/index/file",
        "star": "/path/to/star/index/file",
        "bismark": "/path/to/bismark/index/file",
        "gtf": "/path/to/gtf/file",
        "bed12": "/path/to/bed12/file",
        "readme": "/path/to/readme/file",
        "mito_name": "MT",
        "macs_gsize": "2.7e9",
        "blacklist": "/path/to/blacklist/file"
    }

    genome_instance = Genome(**genome_version)

    assert genome_instance.bismark == genome_version['bismark']
    assert genome_instance.bed12 == genome_version['bed12']
    assert genome_instance.readme == genome_version['readme']
    assert genome_instance.mito_name == genome_version['mito_name']
    assert genome_instance.macs_gsize == genome_version['macs_gsize']
    assert genome_instance.blacklist == genome_version['blacklist']

def test_create_genomeconfig_instance():

    genome_version = {
        "fasta": "/path/to/fasta/file",
        "bwa": "/path/to/bwa/index/file",
        "bowtie2": "/path/to/bowtie2/index/file",
        "gatk": "/path/to/gatk/index/file",
        "samtools": "/path/to/samtools/index/file",
    }

    genome = Genome(**genome_version)

    config = GenomeConfig(genomes={"hg38": genome})

    assert config.genomes == {"hg38": genome}

def test_duplicate_genomes():

    genome1 = Genome(fasta="/path/to/fasta1", 
                     bwa="/path/to/bwa1", 
                     bowtie2="/path/to/bowtie2_1",
                     gatk="/path/to/gatk1",
                     samtools="/path/to/samtools1")
    
    genome2 = Genome(fasta="/path/to/fasta2", 
                     bwa="/path/to/bwa2",
                     bowtie2="/path/to/bowtie2_2",
                     gatk="/path/to/gatk2",
                     samtools="/path/to/samtools2")

    config = GenomeConfig(genomes={"hg38": genome1})

    config.add_genome("hg39", genome2)

    assert config.genomes["hg38"] == genome1
    assert config.genomes["hg39"] == genome2

    try:
        config.add_genome("hg38", genome2)
    except ValueError as e:
        assert str(e) == "Genome 'hg38' already exists in the configuration file."
    else:
        assert False, "Expected ValueError not raised for duplicate genome name."