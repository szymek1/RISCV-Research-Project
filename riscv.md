# RISC-V 32I Instruction Overview

## Instructions

An overview of all supported instructions and what computations are involved.

| Instruction | Type | `pc`         | `rd`             | Other calculations     |
|-------------|------|--------------|------------------|------------------------|
| OP          | R    | `pc + 4`     | `rs1 op rs2`     | -                      |
| OP-IMM      | I    | `pc + 4`     | `rs1 op rs2`     | -                      |
| JAL         | J    | `pc + imm`   | `pc + 4`         | -                      |
| JALR        | I    | `rs1 + imm`  | `pc + 4`         | -                      |
| Branch      | B    | `pc + 4` or `pc + imm` | -      | `rs1 cmp rs2`          |
| LUI         | U    | `pc + 4`     | `imm`            | -                      |
| AUIPC       | U    | `pc + 4`     | `pc + imm`       | -                      |
| LOAD        | I    | `pc + 4`     | `mem[rs1 + imm]` | -                      |
| STORE       | S    | `pc + 4`     | -                | `mem[rs1 + imm] = rs2` |

## Thoughts

Try to figure out what can be computed in the ALU vs where we need extra adders.

It seems that we absolutely need a `pc + imm` adder since during branch instructions, the ALU is occupied with computed the whether to branch or not.
So I was wondering if we can use the `pc + 4` adder for this.
But during AUIPC we need to compute `pc + 4` and `pc + imm`.
We do not need the ALU there though.
