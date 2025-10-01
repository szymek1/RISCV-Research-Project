# -----------------------------------------------------------------------
# Author: Szymon Bogus
# Date:   10.09.2025
#
# Description:
# Script used to find dependencies from testbenches to simulate.
# It is supposed to deliver to simulate.tcl only the HDL modules which
# are included within a particular testbench/testbenches to accelerate the 
# compilation time (no more compiling all the sources for a single test)
# and exclude from compilations irrelevant designs.
# run: $ python3 dep_analyzer.py --lang HDL --tbs "module1_tb module2_tb" --hdl_dir ../src/hdl/ --sim_dir ../src/sim
# TODO: group testbenches and their corresponding sources so sources don't get
#       compiled multiple times, when they belong to only a specific testbench
# License: GNU GPL
# -----------------------------------------------------------------------
import re
import sys
import argparse
from pathlib import Path, PurePath
from collections import defaultdict
from typing import Tuple, List


def parse_instantiations(file_path: str, lang: str) -> List[str]:
    insts = []
    
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('//') or line.startswith('--') or not line: continue  # skip comments/empty
            if lang in ['verilog', 'sv']:
                match = re.match(r'^\s*(\w+)\s+\w+\s*\(', line)
            elif lang == 'vhdl':
                match = re.match(r'^\s*(\w+)\s*:\s*entity\s*\w+\.\w+', line)  # rough VHDL entity inst
            if match:
                submodule = match.group(1).lower()
                if submodule not in ['and', 'or', 'not', 'xor', 'nand', 'nor', 'buf']:  # ignore primitives
                    insts.append(submodule)
                    
    return insts

def build_dep_graph(hdl_dir: str, sim_dir: str, lang: str, ext: str) -> Tuple[dict, dict]:
    hdl_path = Path(hdl_dir)
    sim_path = Path(sim_dir)
    
    graph = defaultdict(list)  # mod -> [submods]
    
    mod_to_file = {}  # mod -> file_path
    all_files = list(hdl_path.glob(f'*.{ext}')) + list(sim_path.glob(f'*.{ext}'))
    
    for file in all_files:
        mod_name = file.stem.lower()  # Assume filename = module
        mod_to_file[mod_name] = str(file)
        submods = parse_instantiations(file, lang)
        graph[mod_name] = submods
        
    return graph, mod_to_file

def collect_deps(graph: dict, tbs: List[str], visited=None) -> set:
    if visited is None: visited = set()
    
    for tb in tbs:
        if tb in visited: continue
        visited.add(tb)
        for sub in graph[tb]:
            collect_deps(graph, [sub], visited)
            
    return visited


if __name__ == "__main__":    
    parser = argparse.ArgumentParser()
    
    parser.add_argument("--lang", type=str, choices=["verilog", "vhdl", "sv"], help="HDL: verilog/vhdl/sv")
    parser.add_argument("--tbs", type=str, help='Space-separated testbench names, e.g., "top_tb other_tb"')
    parser.add_argument("--hdl_dir", type=str, help="Path to src/hdl/")
    parser.add_argument("--sim_dir", type=str, help="Path to src/sim/")

    args = parser.parse_args()
    
    tbs = [t.lower() for t in args.tbs.split(' ')]
    ext = 'v' if args.lang == 'verilog' else 'sv' if args.lang == 'sv' else 'vhdl'  # map language to extension
    
    graph, mod_to_file = build_dep_graph(args.hdl_dir, args.sim_dir, args.lang, ext)
    needed_mods = collect_deps(graph, tbs)
    needed_files = [mod_to_file[m] for m in needed_mods if m in mod_to_file]
    if not needed_files:
        raise FileNotFoundError("Couldnt find source files for testbenches: {} within hdl dir: {} and sim dir: {}".format(tbs, args.hdl_dir, args.sim_dir))
    
    print(' '.join(sorted(needed_files)))