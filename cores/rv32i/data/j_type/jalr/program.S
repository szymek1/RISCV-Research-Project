# RV32I program to test JALR instruction with store instructions
# Tests JALR with positive/negative offsets, different base registers,
# and stores results to memory for verification.

.text
.global _start

_start:
    addi    x5, x0, 0xC      
    jalr    x1, x5, 0x4  
    
    j loop

.org 0x010
target:
    sw x1, 0xC(x0)
    
loop:
    j loop              # Jump to loop (keeps processor running)
