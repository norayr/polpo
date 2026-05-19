#add in ~/.Xresources

#polpoXTerm*pointerMode: 2
#polpoXTerm*maxGraphicSize: 3000x2000
#polpoXTerm*sixelScrolling: true
#polpoXTerm*sixelScrollsRight: true

# then do `xrdb -merge ~/.Xresources`

#xterm -ti vt340 -tn vt340 -geometry 200x70   -xrm 'XTerm*maxGraphicSize: 3000x2000'   -xrm 'XTerm*sixelScrolling: true'   -xrm 'XTerm*sixelScrollsRight: true'   -fa 'monospace' -fs 10
export OWIDTH=1500
export OHEIGHT=1000
export SXL_MOUSE_SKIP=1
export SXL_QUIET_MS=1

xterm -name polpo  -ti vt340 -tn vt340 -geometry 200x70 \
  -xrm 'XTerm*pointerMode: 2' \
  -xrm 'XTerm*maxGraphicSize: 3000x2000' \
  -xrm 'XTerm*sixelScrolling: true' \
  -xrm 'XTerm*sixelScrollsRight: true' \
  -fa 'monospace' -fs 10 -e ./xoberon

# in xterm
#OWIDTH=1500 OHEIGHT=1000 ./xoberon
