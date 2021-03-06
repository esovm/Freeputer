#!/bin/bash
if [ $# -eq 0 ]
  then
    echo "Specify input filename without .fp2 extension:"
    echo "  ./build.sh exampleProgram"
    exit
fi
sed -r 's/([z][0-9a-f]+)\.([x][0-9a-f]+)/\1(\2)/g' <$1.fp2 >$1.m4 \
&& m4 -d $1.m4 > $1.c \
&& make good OBJ=fvm2
