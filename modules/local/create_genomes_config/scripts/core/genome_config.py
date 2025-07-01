from pydantic import BaseModel, Field, model_validator
from typing import Optional, Dict

class Genome(BaseModel):
    """
    Represents a single genome configuration with required and optional fields.
    Required fields are fasta, bwa, and bowtie2.
    Optional fields include star, bismark, gtf, bed12, readme,
    mito_name, macs_gsize, and blacklist.
    """
    fasta: str
    bwa: str
    bowtie2: str
    gatk: str
    samtools: str
    star: Optional[str] = None
    bismark: Optional[str] = None
    gtf: Optional[str] = None
    bed12: Optional[str] = None
    readme: Optional[str] = None
    mito_name: Optional[str] = None
    macs_gsize: Optional[str] = None
    blacklist: Optional[str] = None

class GenomeConfig(BaseModel):
    """
    Represents a configuration file containing multiple genomes.
    The genomes are stored in a dictionary with genome names as keys.
    The configuration ensures that genome names are unique.
    """
    genomes: Dict[str, Genome] = Field(default_factory=dict)

    @model_validator(mode="before")
    @classmethod
    def ensure_unique_keys(cls, values):
        if "genomes" in values:
            keys = list(values["genomes"].keys())
            if len(keys) != len(set(keys)):
                raise ValueError("Duplicate genome keys found in genomes dict.")
        return values

    def add_genome(self, name: str, genome: Genome):
        if name in self.genomes:
            raise ValueError(f"Genome '{name}' already exists in the configuration file.")
        self.genomes[name] = genome