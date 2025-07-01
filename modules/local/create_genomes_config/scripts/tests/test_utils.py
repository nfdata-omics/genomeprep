import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from core.genome_config import Genome, GenomeConfig
from utils.config_utils import genome_config_to_nf_params, write_to_file, read_config_file

def test_converting_genome_config_to_nf_params():
    genome_version = {
        "fasta": "/path/to/fasta/file",
        "bwa": "/path/to/bwa/index/file",
        "bowtie2": "/path/to/bowtie2/index/file",
        "gatk": "/path/to/gatk/index/file",
        "samtools": "/path/to/samtools/index/file",
    }

    genome = Genome(**genome_version)
    config = GenomeConfig(genomes={"hg38": genome})

    nf_params_str = genome_config_to_nf_params(config)

    assert "params {" in nf_params_str
    assert "genomes {" in nf_params_str
    assert "'hg38' {" in nf_params_str
    assert 'fasta' in nf_params_str and '"/path/to/fasta/file"' in nf_params_str
    assert 'bwa' in nf_params_str and '"/path/to/bwa/index/file"' in nf_params_str
    assert 'bowtie2' in nf_params_str and '"/path/to/bowtie2/index/file"' in nf_params_str
    assert 'gatk' in nf_params_str and '"/path/to/gatk/index/file"' in nf_params_str
    assert 'samtools' in nf_params_str and '"/path/to/samtools/index/file"' in nf_params_str

def test_writing_config_to_file():
    genome_version = {
        "fasta": "/path/to/fasta/file",
        "bwa": "/path/to/bwa/index/file",
        "bowtie2": "/path/to/bowtie2/index/file",
        "gatk": "/path/to/gatk/index/file",
        "samtools": "/path/to/samtools/index/file",
    }

    genome = Genome(**genome_version)
    config = GenomeConfig(genomes={"hg38": genome})

    nf_params_str = genome_config_to_nf_params(config)

    write_to_file(nf_params_str)
    assert os.path.exists("genomes.config")
    with open("genomes.config", "r") as f:
        content = f.read()
        assert "params {" in content
        assert "genomes {" in content
        assert "'hg38' {" in content
        assert 'fasta' in content and '"/path/to/fasta/file"' in content
        assert 'bwa' in content and '"/path/to/bwa/index/file"' in content
        assert 'bowtie2' in content and '"/path/to/bowtie2/index/file"' in content
        assert 'gatk' in content and '"/path/to/gatk/index/file"' in content
        assert 'samtools' in content and '"/path/to/samtools/index/file"' in content

def test_read_config_file():
    genome1 = {
        "fasta": "/path/to/fasta/file",
        "bwa": "/path/to/bwa/index/file",
        "bowtie2": "/path/to/bowtie2/index/file",
        "gatk": "/path/to/gatk/index/file",
        "samtools": "/path/to/samtools/index/file",
    }

    genome2 = {
        "fasta": "/path/to/another/fasta/file",
        "bwa": "/path/to/another/bwa/index/file",
        "bowtie2": "/path/to/another/bowtie2/index/file",
        "gatk": "/path/to/another/gatk/index/file",
        "samtools": "/path/to/another/samtools/index/file",
    }

    genome1 = Genome(**genome1)
    genome2 = Genome(**genome2)

    config = GenomeConfig(genomes={"hg38": genome1, "hg19": genome2})

    nf_params_str = genome_config_to_nf_params(config)
    
    # Write to a temporary file
    write_to_file(nf_params_str)

    # Read the configuration back
    read_config = read_config_file("genomes.config")
    
    assert read_config.genomes["hg38"].fasta == "/path/to/fasta/file"
    assert read_config.genomes["hg38"].bwa == "/path/to/bwa/index/file"
    assert read_config.genomes["hg38"].bowtie2 == "/path/to/bowtie2/index/file"
    assert read_config.genomes["hg19"].fasta == "/path/to/another/fasta/file"
    assert read_config.genomes["hg19"].bwa == "/path/to/another/bwa/index/file"
    assert read_config.genomes["hg19"].bowtie2 == "/path/to/another/bowtie2/index/file"