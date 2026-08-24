log "Emulator wrappers"
cat > /usr/local/libexec/opi-emulators/ps1 <<'EOF'
#!/usr/bin/env bash
exec duckstation -batch "$1"
EOF
cat > /usr/local/libexec/opi-emulators/ps2 <<'EOF'
#!/usr/bin/env bash
exec armsx2 "$1"
EOF
cat > /usr/local/libexec/opi-emulators/psp <<'EOF'
#!/usr/bin/env bash
exec ppsspp "$1"
EOF
cat > /usr/local/libexec/opi-emulators/n64 <<'EOF'
#!/usr/bin/env bash
exec rmg "$1"
EOF
cat > /usr/local/libexec/opi-emulators/dreamcast <<'EOF'
#!/usr/bin/env bash
exec flycast "$1"
EOF
cat > /usr/local/libexec/opi-emulators/gc <<'EOF'
#!/usr/bin/env bash
exec dolphin-emu -b -e "$1"
EOF
cat > /usr/local/libexec/opi-emulators/wii <<'EOF'
#!/usr/bin/env bash
exec dolphin-emu -b -e "$1"
EOF
cat > /usr/local/libexec/opi-emulators/gb <<'EOF'
#!/usr/bin/env bash
exec sameboy "$1"
EOF
cp /usr/local/libexec/opi-emulators/gb /usr/local/libexec/opi-emulators/gbc
cat > /usr/local/libexec/opi-emulators/gba <<'EOF'
#!/usr/bin/env bash
exec mgba-qt "$1"
EOF
cat > /usr/local/libexec/opi-emulators/nds <<'EOF'
#!/usr/bin/env bash
exec melonds "$1"
EOF
cat > /usr/local/libexec/opi-emulators/n3ds <<'EOF'
#!/usr/bin/env bash
exec azahar "$1"
EOF
cat > /usr/local/libexec/opi-emulators/nes <<'EOF'
#!/usr/bin/env bash
exec nestopia "$1"
EOF
cat > /usr/local/libexec/opi-emulators/snes <<'EOF'
#!/usr/bin/env bash
exec snes9x-gtk "$1"
EOF
chmod 0755 /usr/local/libexec/opi-emulators/*

log "ROM directories and ES-DE custom systems"
install -d -o ryan -g ryan /home/ryan/ROMs/{ps1,ps2,psp,n64,dreamcast,gc,wii,gb,gbc,gba,nds,n3ds,nes,snes,ports}
install -d -o ryan -g ryan /home/ryan/.emulationstation/custom_systems
cat > /home/ryan/.emulationstation/custom_systems/es_systems.xml <<'EOF'
<?xml version="1.0"?>
<systemList>
  <system><name>ps1</name><fullname>Sony PlayStation</fullname><path>~/ROMs/ps1</path><extension>.cue .chd .iso .pbp .CUE .CHD .ISO .PBP</extension><command>/usr/local/libexec/opi-emulators/ps1 %ROM%</command><platform>psx</platform><theme>psx</theme></system>
  <system><name>ps2</name><fullname>Sony PlayStation 2</fullname><path>~/ROMs/ps2</path><extension>.iso .chd .ISO .CHD</extension><command>/usr/local/libexec/opi-emulators/ps2 %ROM%</command><platform>ps2</platform><theme>ps2</theme></system>
  <system><name>psp</name><fullname>Sony PSP</fullname><path>~/ROMs/psp</path><extension>.iso .cso .chd .ISO .CSO .CHD</extension><command>/usr/local/libexec/opi-emulators/psp %ROM%</command><platform>psp</platform><theme>psp</theme></system>
  <system><name>n64</name><fullname>Nintendo 64</fullname><path>~/ROMs/n64</path><extension>.z64 .n64 .v64 .zip .Z64 .N64 .V64 .ZIP</extension><command>/usr/local/libexec/opi-emulators/n64 %ROM%</command><platform>n64</platform><theme>n64</theme></system>
  <system><name>dreamcast</name><fullname>Sega Dreamcast</fullname><path>~/ROMs/dreamcast</path><extension>.chd .cdi .gdi .CHD .CDI .GDI</extension><command>/usr/local/libexec/opi-emulators/dreamcast %ROM%</command><platform>dreamcast</platform><theme>dreamcast</theme></system>
  <system><name>gc</name><fullname>Nintendo GameCube</fullname><path>~/ROMs/gc</path><extension>.iso .rvz .gcz .ISO .RVZ .GCZ</extension><command>/usr/local/libexec/opi-emulators/gc %ROM%</command><platform>gc</platform><theme>gc</theme></system>
  <system><name>wii</name><fullname>Nintendo Wii</fullname><path>~/ROMs/wii</path><extension>.iso .rvz .wbfs .ISO .RVZ .WBFS</extension><command>/usr/local/libexec/opi-emulators/wii %ROM%</command><platform>wii</platform><theme>wii</theme></system>
  <system><name>gb</name><fullname>Game Boy</fullname><path>~/ROMs/gb</path><extension>.gb .zip .GB .ZIP</extension><command>/usr/local/libexec/opi-emulators/gb %ROM%</command><platform>gb</platform><theme>gb</theme></system>
  <system><name>gbc</name><fullname>Game Boy Color</fullname><path>~/ROMs/gbc</path><extension>.gbc .zip .GBC .ZIP</extension><command>/usr/local/libexec/opi-emulators/gbc %ROM%</command><platform>gbc</platform><theme>gbc</theme></system>
  <system><name>gba</name><fullname>Game Boy Advance</fullname><path>~/ROMs/gba</path><extension>.gba .zip .GBA .ZIP</extension><command>/usr/local/libexec/opi-emulators/gba %ROM%</command><platform>gba</platform><theme>gba</theme></system>
  <system><name>nds</name><fullname>Nintendo DS</fullname><path>~/ROMs/nds</path><extension>.nds .zip .NDS .ZIP</extension><command>/usr/local/libexec/opi-emulators/nds %ROM%</command><platform>nds</platform><theme>nds</theme></system>
  <system><name>n3ds</name><fullname>Nintendo 3DS</fullname><path>~/ROMs/n3ds</path><extension>.3ds .cci .cxi .3DS .CCI .CXI</extension><command>/usr/local/libexec/opi-emulators/n3ds %ROM%</command><platform>3ds</platform><theme>3ds</theme></system>
  <system><name>nes</name><fullname>Nintendo Entertainment System</fullname><path>~/ROMs/nes</path><extension>.nes .zip .NES .ZIP</extension><command>/usr/local/libexec/opi-emulators/nes %ROM%</command><platform>nes</platform><theme>nes</theme></system>
  <system><name>snes</name><fullname>Super Nintendo</fullname><path>~/ROMs/snes</path><extension>.sfc .smc .zip .SFC .SMC .ZIP</extension><command>/usr/local/libexec/opi-emulators/snes %ROM%</command><platform>snes</platform><theme>snes</theme></system>
  <system><name>ports</name><fullname>Ports</fullname><path>~/ROMs/ports</path><extension>.sh .SH</extension><command>%ROM%</command><platform>pc</platform><theme>ports</theme></system>
</systemList>
EOF
chown -R ryan:ryan /home/ryan/.emulationstation /home/ryan/ROMs
install -d -o ryan -g ryan /home/ryan/BIOS/{ps1,ps2,psp,n64,dreamcast,gc,wii,gb,gbc,gba,nds,n3ds,nes,snes}
cat > /home/ryan/BIOS/README.txt <<'EOF'
Place only BIOS/firmware files you legally own in the matching system folder.
No copyrighted BIOS files are included.
EOF
chown -R ryan:ryan /home/ryan/BIOS
