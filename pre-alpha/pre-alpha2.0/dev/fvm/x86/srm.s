/*
                      SINGLE REGISTER MACHINE (SRM)

Copyright © 2017, Robert Gollagher.
SPDX-License-Identifier: GPL-3.0+

Program:    srm
Author :    Robert Gollagher   robert.gollagher@freeputer.net
Created:    20170709
Updated:    20170715+
Version:    pre-alpha-0.0.0.4 for FVM 2.0


                              This Edition:
                           32-bit i386 native
                          x86 Assembly Language
                           using GNU Assembler

                               ( ) [ ] { }

This experimental version uses macros and is compiled to native x86.
Therefore this can easily be ported to other architectures such as ARM.
Once experimentation is complete an interpreted VM will also be implemented.
Note: it perhaps makes sense to make this a Harvard architecture.

==============================================================================
                            BUILDING FOR i386
==============================================================================

For debugging build with:

  as -g --gstabs -o fvm.o fvm.s --32
  gcc -o fvm fvm.o -m32

For release build with:

  as -o fvm.o fvm.s --32
  gcc -o fvm fvm.o -m32

Alternative if no imports:

  as -o fvm.o fvm.s --32
  ld -o fvm fvm.o -m elf_i386

==============================================================================
 WARNING: This is pre-alpha software and as such may well be incomplete,
 unstable and unreliable. It is considered to be suitable only for
 experimentation and nothing more.
============================================================================*/
# ============================================================================
#                                IMPORTS
# ============================================================================
.extern printf

# ============================================================================
#                                SYMBOLS
# ============================================================================
.equ SUCCESS, 0x00
.equ FAILURE, 0x01
.equ MM_BYTES, 0x01000000
.equ vA, %ebx
.equ vC, %edx
.equ rA, %eax
.equ rC, %ecx

# ============================================================================
.section .data #                CONSTANTS
# ============================================================================
version: .asciz "SRM 0.0.0.0\n"
exit: .asciz "SRM exit code: "
illegal: .asciz "SRM illegal opcode with metadata: "
format_hex8: .asciz "%08x"
newline: .asciz "\n"
space: .asciz " "

# ============================================================================
#                             INSTRUCTION SET
# ============================================================================
/*

  LATEST THOUGHTS:   ?sign, sign-extending

  - FW32
  - word-addressing, 32-bit address space
  - 1 bit: reserved
  - 1 bit: instruction format (regular, jump)
  - 2 bits: mode (imm|@,@@,@@++,--@@) (not orthogonal)
  - 4 bits: opcode: (all one-directional M->R)
      - lit, from, to = 3
      - add, sub, mul, div = 4
      - shl, shr, and, or, xor = 5
      - reserved1, reserved2, nop, halt = 3
  - jumps: always absolute
      - jmp, jz, jnz, jlz, jgz, jo = 6
      - skip, skz, sknz, sklz, skgz, sko, skeq, skne, skle, skge = 10
  - 24 bits: metadata

  PREFERRED:

  - bit-30 overflow solutions and 15-bit multiply, not sure div ?? carry, overflow

*/

# ----------------------------------------------------------------------------
#                                STORE MACROS
# ----------------------------------------------------------------------------
# M = @x
.macro dst x
  movl $\x, rA
  movl vA, memory(,rA,1)
.endm

# M = @@x
.macro dst_at x
  movl $\x, rA
  movl memory(,rA,1), rA
  movl vA, memory(,rA,1)
.endm

# M = @@x++
.macro dst_pp x
  movl $\x, rC
  movl memory(,rC,1), rA
  movl vA, memory(,rA,1)
  addl $4, memory(,rC,1)
.endm

# M = --@@x
.macro dst_mm x
  movl $\x, rA
  movl memory(,rA,1), rC
  subl $4, rC
  movl rC, memory(,rA,1)
  movl vA, memory(,rC,1)
.endm

# ----------------------------------------------------------------------------
#                                 LOAD MACROS
# ----------------------------------------------------------------------------
# This may be used after each of the below
.macro rA_mem_vA
  movl memory(,rA,1), vA
.endm

# rA = @x
.macro src x
  movl $\x, rA
.endm

# rA = @@x
.macro src_at x
  movl $\x, rA
  movl memory(,rA,1), rA
.endm

# rA = @@x++
.macro src_pp x
  movl $\x, rC
  movl memory(,rC,1), rA
  addl $4, memory(,rC,1)
.endm

# rA = --@@x
.macro src_mm x
  movl $\x, rA
  movl memory(,rA,1), rC
  subl $4, rC
  movl rC, memory(,rA,1)
.endm

# ----------------------------------------------------------------------------
#                                ARITHMETIC MACROS
# ----------------------------------------------------------------------------
.macro divide metadata
  movl vA, %eax
  movl $\metadata, %ebx

  test %ebx, %ebx
  je 1f

  cdq             # MUST widen %eax here to %edx:eax or (neg) div wrong
  idivl %ebx      # %edx:eax is the implied dividend
  jmp 2f
  1: # Division by zero
    movl $0, vA
  2:
.endm

# ----------------------------------------------------------------------------
#                                   JUMP MACROS
# ----------------------------------------------------------------------------
.macro doJump label # FIXME difficult, need to make indirect
  jmp \label
.endm

.macro doJmpo label
  andl vA, $0x80000000
  jz positive
    andl vA, $0x40000000
    jnz ok
      jmp \label
  positive:
    andl vA, $0x40000000
    jz ok
      jmp \label
  ok:
.endm

.macro doJmpz label
  xorl $0, vA
  jnz 1f
    jmp \label
  1:
.endm

.macro doJmpnz label
  xorl $0, vA
  jz 1f
    jmp \label
  1:
.endm

.macro doJmplt label
  cmp $0, vA
  jgt 1f
    jmp \label
  1:
.endm

.macro doJmpgt label
  cmp $0, vA
  jlt 1f
    jmp \label
  1:
.endm

# ----------------------------------------------------------------------------
#                             MOVE INSTRUCTIONS
# ----------------------------------------------------------------------------
.macro lit metadata
  movl $\metadata, rA
.endm
# ----------------------------------------------------------------------------
.macro from metadata
  src metadata
  rA_mem_vA
.endm

.macro from_at metadata
  src_at metadata
  rA_mem_vA
.endm

.macro from_pp metadata
  src_pp metadata
  rA_mem_vA
.endm

.macro from_mm metadata
  src_mm metadata
  rA_mem_vA
.endm
# ----------------------------------------------------------------------------
.macro to metadata
  dst metadata
.endm

.macro to_at metadata
  dst_at metadata
.endm

.macro to_pp metadata
  dst_pp metadata
.endm

.macro to_mm metadata
  dst_mm metadata
.endm
# ----------------------------------------------------------------------------
#                           ARITHMETIC INSTRUCTIONS
# ----------------------------------------------------------------------------
.macro add metadata
  addl $\metadata, vA
.endm

.macro add_at metadata
  src_at metadata
  addl rA, vA
.endm

.macro add_pp metadata
  src_pp metadata
  addl rA, vA
.endm

.macro add_mm metadata
  src_mm metadata
  addl rA, vA
.endm
# ----------------------------------------------------------------------------
.macro sub metadata
  subl $\metadata, vA
.endm

.macro sub_at metadata
  src_at metadata
  subl rA, vA
.endm

.macro sub_pp metadata
  src_pp metadata
  subl rA, vA
.endm

.macro sub_mm metadata
  src_mm metadata
  subl rA, vA
.endm
# ----------------------------------------------------------------------------
.macro mul metadata
  mull $\metadata, vA
.endm

.macro mul_at metadata
  src_at metadata
  mull rA, vA
.endm

.macro mul_pp metadata
  src_pp metadata
  mull rA, vA
.endm

.macro mul_mm metadata
  src_mm metadata
  mull rA, vA
.endm
# ----------------------------------------------------------------------------
.macro div metadata
  divide metadata
.endm

.macro div_at metadata
  src_at metadata
  rA_mem_vA
  divide metadata
.endm

.macro div_pp metadata
  src_pp metadata
  rA_mem_vA
  divide metadata
.endm

.macro div_mm metadata
  src_mm metadata
  rA_mem_vA
  divide metadata
.endm

# ----------------------------------------------------------------------------
#                               BITWISE INSTRUCTIONS
# ----------------------------------------------------------------------------
.macro or metadata
  orl $\metadata, vA
.endm

.macro or_at metadata
  src_at metadata
  orl rA, vA
.endm

.macro or_pp metadata
  src_pp metadata
  orl rA, vA
.endm

.macro or_mm metadata
  src_mm metadata
  orl rA, vA
.endm
# ----------------------------------------------------------------------------
.macro and metadata
  andl $\metadata, vA
.endm

.macro and_at metadata
  src_at metadata
  andl rA, vA
.endm

.macro and_pp metadata
  src_pp metadata
  andl rA, vA
.endm

.macro and_mm metadata
  src_mm metadata
  andl rA, vA
.endm
# ----------------------------------------------------------------------------
.macro xor metadata
  xorl $\metadata, vA
.endm

.macro xor_at metadata
  src_at metadata
  xorl rA, vA
.endm

.macro xor_pp metadata
  src_pp metadata
  xorl rA, vA
.endm

.macro xor_mm metadata
  src_mm metadata
  xorl rA, vA
.endm
# ----------------------------------------------------------------------------
.macro shl metadata
  movl $\metadata, rA
  movl rA, %ecx
  shll %cl, vA
.endm

.macro shl_at metadata
  src_at metadata
  movl rA, %ecx
  shll %cl, vA
.endm

.macro shl_pp metadata
  src_pp metadata
  movl rA, %ecx
  shll %cl, vA
.endm

.macro shl_mm metadata
  src_mm metadata
  movl rA, %ecx
  shll %cl, vA
.endm
# ----------------------------------------------------------------------------
.macro shr metadata
  movl $\metadata, rA
  movl rA, %ecx
  shrl %cl, vA
.endm

.macro shr_at metadata
  src_at metadata
  movl rA, %ecx
  shrl %cl, vA
.endm

.macro shr_pp metadata
  src_pp metadata
  movl rA, %ecx
  shrl %cl, vA
.endm

.macro shr_mm metadata
  src_mm metadata
  movl rA, %ecx
  shrl %cl, vA
.endm
# ----------------------------------------------------------------------------
#                               JUMP INSTRUCTIONS
# ----------------------------------------------------------------------------
.macro jump label
  doJump \label
.endm

.macro jmpo label
  doJmpo \label
.endm

.macro jmpz label
  doJmpz \label
.endm

.macro jmpnz label
  doJmpnz \label
.endm

.macro jmplt label
  doJmplt \label
.endm

.macro jmpgt label
  doJmpgt \label
.endm
# ----------------------------------------------------------------------------


# ----------------------------------------------------------------------------
#                            OTHER INSTRUCTIONS
# ----------------------------------------------------------------------------
.macro nop
.endm

.macro reserved1 metadata
  movl $\metadata, %eax
  jmp vm_illegal
.endm

.macro reserved2 metadata
  movl $\metadata, %eax
  jmp vm_illegal
.endm

.macro halt metadata
  movl $\metadata, %eax
  jmp vm_exit
.endm

# ============================================================================
.section .bss #                  VARIABLES
# ============================================================================
memory: .lcomm mm, MM_BYTES

# ============================================================================
#                                 TRACING
# ============================================================================
.macro TRACE_STR strz
  SAVE_REGS
  pushl \strz
  call printf
  addl $4, %esp
  RESTORE_REGS
.endm

.macro TRACE_HEX8 rSrc
  SAVE_REGS
  pushl %eax
  pushl \rSrc
  pushl $format_hex8
  call printf
  addl $8, %esp
  popl %eax
  RESTORE_REGS
.endm

.macro SAVE_REGS
  pushal
.endm

.macro RESTORE_REGS
  popal
.endm

# ============================================================================
#                            EXAMPLE VARIABLES
# ============================================================================
.equ a, 0x00
.equ b, 0x04
.equ c, 0x08
.equ counter, 0x0c
.equ ptr, 0x10

# ============================================================================
.section .text #                ENTRY POINT
# ============================================================================
.global main
main:

  halt 0x12345678


vm_illegal:

  TRACE_STR $illegal
  TRACE_HEX8 rA
  TRACE_STR $newline
  ret

vm_exit:

  TRACE_STR $exit
  TRACE_HEX8 rA
  TRACE_STR $newline
  ret

# ============================================================================