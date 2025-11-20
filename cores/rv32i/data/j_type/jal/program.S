# Simple RV32I program using J-type, R-type, S-type and I-type instructions
# Executes load instructions, jumps to a subroutine and performs ALU operations and stores the data.

.text
.global _start

_start:
    lw x5, 0(x10)            # x5 = mem[0x0000] = 0x00000004
    lw x6, 4(x10)            # x6 = mem[0x0004] = 0x00000003
    sw x6, 0xC(x0)

    jal x1, target           # Jump to target, x1 = pc + 4
    lw x7, 8(x10)            # x7 = mem[0x0008] = 0x00000008
    j loop

target:
    nop                      # Placeholder at target
    j return_point           # Return to after jal

return_point:
    sw x5, 0xA(x0)           # Store x5 after return
    jal x1, far_target       # Jump further
    nop
    nop
    jal x1, back             # Jump back
    j end

far_target:
    nop
    j return_point

back:
    nop
    j return_point

loop:
    j loop

end:
    j end