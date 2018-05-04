/*
Copyright © 2018, Robert Gollagher.
SPDX-License-Identifier: GPL-3.0+

Program:    exampleProgram.m4
Author :    Robert Gollagher   robert.gollagher@freeputer.net
Created:    20180503
Updated:    20180504+
Version:    pre-alpha-0.0.0.5+ for FVM 2.0

This is an example program using the 'fvm2.c' virtual machine definition.

To build it do:

  m4 exampleProgram.m4 > exampleProgram.c

The resulting 'exampleProgram.c' should never be modified by hand.
It is currently included in 'fvm2.c' which you can then build and run by:

  make good OBJ=fvm2
  time ./fvm2; echo $?

If you wish to examine the output of the C preprocessor you can do:

  gcc -E fvm2.c

==============================================================================
 WARNING: This is pre-alpha software and as such may well be incomplete,
 unstable and unreliable. It is considered to be suitable only for
 experimentation and nothing more.
============================================================================*/
// m4: define(`CONCAT',`$1$2$3')
// m4: define(`as',`define(`thismn',`$1')')
// m4: define(`export',CONCAT(thismn(),_,$1):)
// m4: define(`use',`#define $1(xn) $2_ ## xn')
// m4: define(`endmod',`#include "endmod.c"')
/* =========================================================================*/

jump(m0_x0) /*run.main*/

// ---------------------------------------------------------------------------
  as(m4)
  module(math)
    atom(add)
      export(x1)
        add
        ret
    endat
  endmod

// ---------------------------------------------------------------------------
  as(m3)
  module(prn)
    unit(modName)
      export(x0) u0:
        i(0x6d)
        out
        out
        i(0x0a)
        out
        ret
    endun
    unit(prnIdent)
      export(x1)
        i(0x33)
        call(u0) /*modName*/
        ret
    endun
  endmod

// ---------------------------------------------------------------------------
  as(m1)
  use(z1,m3) /*prn*/
  module(foo)
    unit(prnIdent)
      export(x0)
        i(0x31)
        call(z1(x0)) /*prn.modName*/
        ret
    endun
  endmod

// ---------------------------------------------------------------------------
  as(m2)
  use(z1,m3) /*prn*/
  module(bar)
    unit(prnIdent)
      export(x0)
        i(0x32)
        call(z1(x0)) /*prn.modName*/
        ret
    endun
  endmod

// ---------------------------------------------------------------------------

  as(m0)
  use(z1,m1) /*foo*/
  use(z2,m2) /*bar*/
  use(z3,m3) /*prn*/
  use(z4,m4) /*math*/
  module(run)
    unit(main)
      export(x0)
        call(z1(x0)) /*foo.prnIdent*/ // Should print "m1\n"
        call(z2(x0)) /*bar.prnIdent*/ // Should print "m2\n"
        call(z3(x1)) /*prn.prnIdent*/ // Should print "m3\n"

        i(0x40)
        i(1)
        call(z4(x1)) /*math.add*/
        out
        i(0xa)
        out // Should print "A\n"

        tron

        i(0x41424344)
        i(0)
        hold
        i(0)
        give

        outw
        i(0xa)
        out // Should print "DCBA\n" (note: all is little endian, for now)

        inw // If we read "1234\n"...
        outw
        i(0xa)
        out // ...then this should print "1234\n"

        halt
    endun
  endmod