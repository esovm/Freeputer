/*
Copyright © 2017, Robert Gollagher.
SPDX-License-Identifier: GPL-3.0+

Program:    qmisc.c
Author :    Robert Gollagher   robert.gollagher@freeputer.net
Created:    20170729
Updated:    20180429+
Version:    pre-alpha-0.0.7.0+ for FVM 2.0
=======

                              This Edition:
                               Portable C
                            for Linux and gcc

                               ( ) [ ] { }

  Removed most notes so as not to prejudice lateral thinking during design.

  MAJOR CHANGE:
    There is now a link stack rather than a link register.
    The terminology is go and resume (analagous to call and return).
    The current number of elements on the link stack is held in vL.
    The link stack is intentionally small and of a fixed size.

==============================================================================
 WARNING: This is pre-alpha software and as such may well be incomplete,
 unstable and unreliable. It is considered to be suitable only for
 experimentation and nothing more.
============================================================================*/
#define TRACING_ENABLED // Comment out unless debugging

#include <stdio.h>
#include <inttypes.h>
#include <assert.h>
#define WORD uint32_t
#define WD_BYTES 4
#define WD_BITS WD_BYTES*8
#define MSb 0x80000000 // Bit mask for most significant bit
#define LNKT uintptr_t
#define METADATA WORD
#define METADATA_MASK 0x7fffffff // 31 bits
#define BYTE_MASK     0x000000ff
#define SHIFT_MASK    0x0000001f
#define SUCCESS 0
#define FAILURE 1
#define ILLEGAL 2
#define LS_UNDERFLOW 3
#define LS_OVERFLOW 4
#define MAX_DM_WORDS 0x10000000 // <= 2^(WD_BITS-4) due to C limitations.
#define DM_WORDS  0x10000  // Must be some power of 2 <= MAX_DM_WORDS.
#define DM_MASK   DM_WORDS-1
#define LS_LNKTS  0x100
#define vL_MAX    LS_LNKTS-1
#define nopasm "nop" // The name of the native hardware nop instruction
// There are only 4 accessible registers:
WORD vA = 0; // accumulator
WORD vB = 0; // operand register
WORD vT = 0; // temporary register
WORD vR = 0; // repeat register
WORD vL = 0; // link counter (not accessible)
LNKT ls[LS_LNKTS]; // link stack (not accessible)
WORD dm[DM_WORDS]; // data memory (Harvard architecture)
int exampleProgram();
// ---------------------------------------------------------------------------
METADATA safe(METADATA addr) { return addr & DM_MASK; }
METADATA enbyte(METADATA x)  { return x & BYTE_MASK; }
METADATA enrange(METADATA x) { return x & METADATA_MASK; }
METADATA enshift(METADATA x) { return x & SHIFT_MASK; }
// ---------------------------------------------------------------------------
// Arithmetic
void Add()    { vA+=vB; }
void Sub()    { vA-=vB; }
// Logic
void Or()     { vA|=vB; }
void And()    { vA&=vB; }
void Xor()    { vA^=vB; } // Maybe add NOT and NEG too
// Shifts
void Shl()    { vA<<=enshift(vB); }
void Shr()    { vA>>=enshift(vB); }
// Moves
void Get()    { vA = dm[safe(vB)]; }
void Put()    { dm[safe(vB)] = vA; }

void Geti()   { WORD sB = safe(vB); vA = dm[safe(dm[sB])]; }
void Puti()   { WORD sB = safe(vB); dm[safe(dm[sB])] = vA; } // untested

void Decm()   { --dm[safe(vB)]; }
void Incm()   { ++dm[safe(vB)]; }

void At()     { vB = dm[safe(vB)]; }
void Copy()   { dm[safe(vB+vA)] = dm[safe(vB)]; } // a smell?
// Increments for addressing
void Inc()    { ++vB; }
void Dec()    { --vB; }
// Immediates
void Imm(METADATA x)    { vB = enrange(x); } // bits 31..0
void Flip()             { vB = vB^MSb; }     // bit  32 (NOT might be better)
// Transfers (maybe expand these)
void Swap()   { vB = vB^vA; vA = vA^vB; vB = vB^vA; }
void Tob()    { vB = vA; }
void Tot()    { vT = vA; }
void Tor()    { vR = vA; }
void Fromb()  { vA = vB; }
void Fromt()  { vA = vT; }
void Fromr()  { vA = vR; }
// Machine metadata
void Mdm()    { vA = DM_WORDS; }
void Lsa()    { vA = LS_LNKTS-vL; }
void Lse()    { vA = vL; }
// Other
void Noop()   { ; }
#define halt return enbyte(vA);
// Jumps (static only), maybe reduce these back to jump and jmpe only
#define jmpa(label) if (vA == 0) { goto label; } // vA is 0
#define jmpb(label) if (vB == 0) { goto label; } // vB is 0
#define jmpe(label) if (vA == vB) { goto label; } // vA equals vB
#define jmpn(label) if (MSb == (vA&MSb)) { goto label; } // MSb set in vA
#define jmps(label) if (vB == (vA&vB)) { goto label; } // all vB 1s set in vA
#define jmpu(label) if (vB == (vA|vB)) { goto label; } // all vB 0s unset in vA
#define jump(label) goto label; // UNCONDITIONAL
#define rpt(label) if ( vR != 0) { --vR; goto label; }
#define go(label) { \
  if (vL<vL_MAX) { \
      __label__ lr; ls[++vL] = (LNKT)&&lr; goto label; lr: ; \
  } else { \
      vA = LS_OVERFLOW; halt \
  } \
}
#define rs { \
  if (vL>0) { \
    goto *(ls[vL--]); \
  } else { \
      vA = LS_UNDERFLOW; halt \
  } \
}
// Basic I/O (experimental)
#define in(label) vA = getchar(); // If fail goto label
#define out(label) putchar(vA); // If fail goto label
// ===========================================================================
#define i(x) Imm(x);
// ===========================================================================
#define dbg \
{ __label__ pc; pc: \
  printf("pc:%08x vA:%08x vB:%08x vT:%08x vR:%08x vL:%08x ls[vL]:%08x -- \
ls[0]:%08x ls[1]:%08x ls[2]:%08x ls[3]:%08x\n", \
&&pc, vA, vB, vT, vR, vL, ls[vL], ls[0], ls[1], ls[2], ls[3]); }
// ===========================================================================
int main() {
  assert(sizeof(WORD) == WD_BYTES);
  return exampleProgram();
}
// ===========================================================================
int exampleProgram() {

dbg
go(x0);
halt 

foo:
  i(4)
  dbg
  rs
bar:
  i(3)
  dbg
  go(foo)
  i(3)
  dbg
  rs
baz:
  i(2)
  dbg
  go(bar)
  i(2)
  dbg
  rs
x0:
  i(1)
  dbg
  go(baz)
  i(1)
  dbg
  rs
}
// ===========================================================================


