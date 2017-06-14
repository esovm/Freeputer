var prgSrc = `( 0x = hex, 0s = symbol, 0f = forward, 0r = reverse)
( #def = definition, / = token is a comment )
#def lit 0x01
#def jmp 0x03
#def nop 0xfd
#def hal 0xff
#def --- 0x000000
#def /foo 0s000001 0x000008
#def /bar 0s000002 /foo 0s000001
/start
  lit 0x000003
  lit /bar 0s000002
  jmp /green 0f000004               ( forward )
  nop ---
  nop ---
/red jmp /end 0f000004              ( forward )
/green jmp /red 0r000001            ( reverse )
  nop ---
  nop ---
/end hal ---
`;
