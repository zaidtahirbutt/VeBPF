#!/bin/bash

# do conda activate hbpf_2 before running this 

total_eBPF_rules=0
verbose=1

# check for all assembly files in current dir
for asm_file in "."/*.asm
do

    if [ -f "$asm_file" ]; then

        echo "File: $asm_file found"
        ((total_eBPF_rules++))
    
    fi

done

if [ $total_eBPF_rules -ne 0 ]; then

    echo "Total eBPF rules = $total_eBPF_rules"

else 

    echo "Please provide eBPF asm file"
    echo "exiting..."
    exit 0

fi

# echo "exiting..."

# exit 0

echo "Compiling and combining asm files binaries for uploading automatically as per v2 of VeBPF prog_loader"

BIN="place_holder.bin"
HEX="combined_hex.hex"

# start of first rule Dword
echo "0xffffffffffffffff" > "$HEX"

for asm_file in "."/*.asm
do

    ASM="$asm_file"

    # Assemble source
    python3 ../../tools/ubpf/bin/ubpf-assembler "./$ASM" "./$BIN"
    
    # Convert compiled eBPF binary to hex and write to hex file
    ../../tools/dump.py "$BIN" >> "$HEX"     

    # check if its the last eBPF asm file

    ((total_eBPF_rules--))

    if [ $total_eBPF_rules -ne 0 ]; then 
        
        # end of current rule Dword (not the last rule)
        echo "0xffffffffffffff0f" >> "$HEX"

        # start of rule Dword (next rule)
        echo "0xffffffffffffffff" >> "$HEX"
    
    else 

        # end of all rules Dword
        echo "0xfffffffffffffff0" >> "$HEX"

    fi

    
done
