import re

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

from core.genome_config import Genome, GenomeConfig

def genome_config_to_nf_params(config: GenomeConfig) -> str:
    out = "params {\n    genomes {\n"
    for name, genome in config.genomes.items():
        out += f"        '{name}' {{\n"
        for k, v in genome.model_dump(exclude_none=True).items():
            out += f'            {k:<12} = "{v}"\n'
        out += "        }\n"
    out += "    }\n}\n"
    return out

def read_config_file(file_path: str) -> GenomeConfig:
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Configuration file '{file_path}' does not exist.")
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    pattern = re.compile(r"'(\w+)' *\{([^}]+)\}", re.MULTILINE)
    genomes = {}

    for match in pattern.finditer(content):
        genome_name = match.group(1)
        block = match.group(2)

        genome_data = {}
        for line in block.strip().splitlines():
            line = line.strip()
            if not line or "=" not in line:
                continue
            key, value = line.split("=", 1)
            genome_data[key.strip()] = value.strip().strip('"')

        genomes[genome_name] = Genome(**genome_data)

    return GenomeConfig(genomes=genomes)

def write_to_file(nf_params, output_file):
    with open(output_file, "w") as f:
        f.write(nf_params)
    logging.info(f"Configuration written to {output_file}")