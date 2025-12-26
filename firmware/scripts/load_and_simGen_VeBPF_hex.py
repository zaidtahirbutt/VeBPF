import serial
import time
import sys
import binascii
import os
import argparse


 # --- CLI arguments ---
parser = argparse.ArgumentParser(description="Load and run VeBPF simulation")
parser.add_argument(
    "--sim_gen",
    type=int,
    default=0,
    help="Simulation generation mode (0 = hardware UART, 1 = simulation). Default = 0"
)
parser.add_argument(
    "--usb",
    type=str,
    default="ttyUSB1",
    help="USB device to use when sim_gen=0 (default: ttyUSB1)"
)
# baud_rate argument (default = 1000000)
parser.add_argument(
    "--baud_rate",
    type=int,
    default=1000000,
    help="Baud rate value (default: 1000000)"
)
args = parser.parse_args()


sim_gen = args.sim_gen 

# VeBPF prog loader version 1 or 2 
VeBPF_program_loader_version = 2

print(f"VeBPF_program_loader_version = {VeBPF_program_loader_version} is being used \n")
print(f'sim_gen = {sim_gen}')

baud_rate = args.baud_rate
# baud_rate = 1204820  # worked when sys clk was 100 MHz! and CLKs per Bit = 83 !
# baud_rate = 921600   # 921600 baudrate for other projects

if (baud_rate != 1000000):
    print(f"Warning, the default value of baud_rate has been changed to {baud_rate} from value of 1000000")
else:
    print(f"Default value of baud_rate = {baud_rate} is being used")

if (sim_gen == 0):

    if (len(sys.argv) == 1):  # meaning no ttyUSB arg was given and its just python3 load.py
    	ser = serial.Serial('/dev/ttyUSB1', baud_rate) # 0 is being used as JTAG to upload bit file and only 1 is avail to be used as UART
        # ser = serial.Serial('/dev/ttyUSB3', 1000000)
    else:
        device = "/dev/" + sys.argv[1]		# I can provide an input USB number that I want
        ser = serial.Serial(device, baud_rate)

tests_dir = os.path.abspath(os.path.dirname(__file__))

##############################################################################################################
######################## START UPLOADING RULES BELOW #########################################################
##############################################################################################################

# VeBPF_pgmLoaderV2 combined eBPF rules automated
# 4 rules 56 pgm words +8 control words
VeBPF_test_dir = 'VeBPF_firewall'
VeBPF_test_file = 'combined_hex.hex'


# Go UP one level from scripts → firmware
firmware_dir = os.path.dirname(tests_dir)
test_path = os.path.join(firmware_dir, VeBPF_test_dir, VeBPF_test_file)
# test_path = os.path.join(tests_dir, VeBPF_test_dir, VeBPF_test_file)

VeBPF_test_file_sim = 'sim_' + VeBPF_test_file 

test_file_dir = os.path.join(firmware_dir, VeBPF_test_dir, VeBPF_test_file_sim)
# test_file_dir = os.path.join(tests_dir, VeBPF_test_dir, VeBPF_test_file_sim)

print("test path = ", test_path)
print("test_file_dir = ", test_file_dir)

# sys.exit("sys exit")
program = []
address = []
counter = 0;

with open(test_path) as file:
    for line in file:
        program_data = line.split('x')[1];
        # print("pgm data = ",program_data)
        program.append(program_data.split('\n')[0])  # to remove the newline at the end of each line
        address.append(counter)
        counter = counter + 1

debug = 0

if(debug==1):
    print("program = ", program)
    print("address = ", address)

if (VeBPF_program_loader_version == 1):
    print(f'VeBPF_program_loader_version = {VeBPF_program_loader_version}')

    if(sim_gen==1):
        with open(test_file_dir, 'w') as f:  
            for word in program:
                # print("word[0] = ", word[0])
                # print("word[1] = ", word[1])
                # print("word[2] = ", word[2])
                # print("word[3] = ", word[3])
                # sys.exit("sys exit")
                # sys.exit("sys exit")
                # word[0] =  b
                # word[1] =  7
                # word[2] =  0
                # word[3] =  2


                # f.write(word[0:3])
                # f.write(word[6:7])
                # f.write(word[4:5])
                # f.write(word[14:15])
                # f.write(word[12:13])
                # f.write(word[10:11])
                # f.write(word[8:9])

                # https://www.geeksforgeeks.org/python-list-slicing/
                    # list slicing says, the right side element is not included

                # as mentioned in the printed word[0] = b, word means 4 bits here... 
                # So word[0:4] means the four hex digits come first as follows:
                # word[0]word[1]word[2]word[3], i.e., b401 as per this file:
                # VeBPF_test_dir = 'data27_a100T25_eBPF_firewall/type1_spoofing_illegal_ip/firewall_rule1_unroutable_ip_1_v2_modified'
                f.write(word[0:4])      # Byte 8 + Byte 7 as per image below
                f.write(word[6:8])      # then Byte 5 as per image below
                f.write(word[4:6])      # then Byte 6 as per image below
                f.write(word[14:16])    # then Byte 1 as per image below (numbering starts at Byte 1 instead of Byte 0 for the sake of our comments here)
                f.write(word[12:14])    # then Byte 2 as per image below
                f.write(word[10:12])    # then Byte 3 as per image below
                f.write(word[8:10])     # then Byte 4 as per image below
                f.write("\n")

                # So in short the byte order for simulation is same as the byte order of SYN when VeBPF rules are being uploaded

                # from synm the eBPF ISA for our VeBPF Syn. lets see if its same as sim:
                # //  // testing
                # //  // MSB                                                        LSB
                # //   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
                # //   // +--------+----+----+----------------+------------------------+
                # //   // |opcode  | src| dst|          offset|               immediate|
                # //   // +--------+----+----+----------------+------------------------+
                # //   // 63     56   52   48               32                        0

                # Program loader loads the first byte in LSB and then move towards loading into LSB...
                    # So load Byte 4-1 first.. then 6-5.... then 7-8

    # sys.exit("sys exit")


    if(sim_gen == 0):
        for i in range(len(program)):
            # send 2 bytes of address
            if (debug==1):
                print("2 address bytes as being uploaded") 
            x = address[i]  
            x1 = (x&255).to_bytes(1, byteorder='big')   # x&(255=0b11111111) setting other bits other than the 8 LSbs to zero
            x2 = ((x>>8)&255).to_bytes(1, byteorder='big')
            
            if (debug==0):
                ser.write(x1) 
            else:
                # print("x1 =", x1)
                print("x1 =", x1.hex())

            time.sleep(0.001)

            if (debug==0):
                ser.write(x2)
            else:
                # print("x2 =", x2)
                print("x2 =", x2.hex())

            time.sleep(0.001)

            # send 8 bytes of program address 
            if (debug==1):
                print("8 prog data bytes as being uploaded") 
            
            x = int(program[i],16)    # print(int("FF", base=16))  #255 # int() converts the input string whose base we mention, into decimal integer 
            x1 = (x&255).to_bytes(1, byteorder='big')   # x&(255=0b11111111) setting other bits other than the 8 LSbs to zero
            x2 = ((x>>8)&255).to_bytes(1, byteorder='big')
            x3 = ((x>>16)&255).to_bytes(1, byteorder='big')
            x4 = ((x>>24)&255).to_bytes(1, byteorder='big')
            x5 = ((x>>32)&255).to_bytes(1, byteorder='big')
            x6 = ((x>>40)&255).to_bytes(1, byteorder='big')
            x7 = ((x>>48)&255).to_bytes(1, byteorder='big')
            x8 = ((x>>56)&255).to_bytes(1, byteorder='big')

            # //  // testing
            # //  // MSB                                                        LSB
            # //   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
            # //   // +--------+----+----+----------------+------------------------+
            # //   // |opcode  | src| dst|          offset|               immediate|
            # //   // +--------+----+----+----------------+------------------------+
            # //   // 63     56   52   48               32                        0

            # Program loader loads the first byte in LSB and then move towards loading into LSB...
                # So load Byte 4-1 first.. then 6-5.... then 7-8

            if (debug==0):
                ser.write(x4)
            else:
                # print("x4 =", x4)
                print("x4 =", x4.hex())
            
            time.sleep(0.001)
            
            if (debug==0):
                ser.write(x3)
            else:
                # print("x3 =", x3)
                print("x3 =", x3.hex())
            
            time.sleep(0.001)
            
            if (debug==0):
                ser.write(x2)
            else:
                # print("x2 =", x2)
                print("x2 =", x2.hex())

            time.sleep(0.001)

            if (debug==0):
                ser.write(x1)
            else:
                # print("x1 =", x1)
                print("x1 =", x1.hex())
            
            time.sleep(0.001)
            
            if (debug==0):
                ser.write(x6)
            else:
                # print("x6 =", x6)
                print("x6 =", x6.hex())
            
            time.sleep(0.001)
            
            if (debug==0):
                ser.write(x5)
            else:
                # print("x5 =", x5)
                print("x5 =", x5.hex())
            
            time.sleep(0.001)
            
            if (debug==0):
                ser.write(x7)
            else:
                # print("x7 =", x7)
                print("x7 =", x7.hex())
            
            time.sleep(0.001)
            
            if (debug==0):
                ser.write(x8)
            else:
                # print("x8 =", x8)
                print("x8 =", x8.hex())
            
            time.sleep(0.001)

            # sys.exit("sys exit")

    # sys.exit("sys exit")

    # print("x_combined is = ",format(x_combined,"08X"))
    #x_combined is =  70326932 , so here the last two extra bytes that werent multiple of 4 bytes i.e., word were left out as well.

    if sim_gen:
        print ("\n\n** Heads up! sim_gen = 1 \n the hex file isn't being uploaded, rather simulation hex file is being generated **\n\n")
        print ("VeBPF prog SIMULATION file creation done")
    else:
        print ("VeBPF prog uploading done")



    # As shown below a few bytes were printed out as @, W, y, $. But when I converted these from hex to string, it was confirmed that these
    # symbols represent the actual hex data in that location in VeBPF program mem.

elif (VeBPF_program_loader_version == 2):
    print(f'VeBPF_program_loader_version = {VeBPF_program_loader_version}')

    if(sim_gen==1):
        with open(test_file_dir, 'w') as f:  
            for word in program:
                # print("word[0] = ", word[0])
                # print("word[1] = ", word[1])
                # print("word[2] = ", word[2])
                # print("word[3] = ", word[3])
                # sys.exit("sys exit")
                # sys.exit("sys exit")
                # word[0] =  b
                # word[1] =  7
                # word[2] =  0
                # word[3] =  2


                # f.write(word[0:3])
                # f.write(word[6:7])
                # f.write(word[4:5])
                # f.write(word[14:15])
                # f.write(word[12:13])
                # f.write(word[10:11])
                # f.write(word[8:9])

                # https://www.geeksforgeeks.org/python-list-slicing/
                    # list slicing says, the right side element is not included

                # as mentioned in the printed word[0] = b, word means 4 bits here... 
                # So word[0:4] means the four hex digits come first as follows:
                # word[0]word[1]word[2]word[3], i.e., b401 as per this file:
                # VeBPF_test_dir = 'data27_a100T25_eBPF_firewall/type1_spoofing_illegal_ip/firewall_rule1_unroutable_ip_1_v2_modified'

                # print(f'word = {word}')
                # if (word == "ffffffffffffffff"):
                #     print(f'Heeeyy ffffffffffffffff')
                # sys.exit("Sys Exiting 1....")
                # if the instruction Dword isn't a starting rule word, current rule end Dword (next rule incoming), last rule end Dword 
                if ((word != ("ffffffffffffffff")) and (word != ("ffffffffffffff0f")) and (word != ("fffffffffffffff0"))):
                    f.write(word[0:4])      # Byte 8 + Byte 7 as per image below
                    f.write(word[6:8])      # then Byte 5 as per image below
                    f.write(word[4:6])      # then Byte 6 as per image below
                    f.write(word[14:16])    # then Byte 1 as per image below (numbering starts at Byte 1 instead of Byte 0 for the sake of our comments here)
                    f.write(word[12:14])    # then Byte 2 as per image below
                    f.write(word[10:12])    # then Byte 3 as per image below
                    f.write(word[8:10])     # then Byte 4 as per image below
                    f.write("\n")
                else:
                    f.write(word)
                    # if its not the last rule Dword flag then add next line
                    if (word != ("fffffffffffffff0")):
                        f.write("\n")

                # So in short the byte order for simulation is same as the byte order of SYN when VeBPF rules are being uploaded

                # from synm the eBPF ISA for our VeBPF Syn. lets see if its same as sim:
                # //  // testing
                # //  // MSB                                                        LSB
                # //   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
                # //   // +--------+----+----+----------------+------------------------+
                # //   // |opcode  | src| dst|          offset|               immediate|
                # //   // +--------+----+----+----------------+------------------------+
                # //   // 63     56   52   48               32                        0

                # Program loader loads the first byte in LSB and then move towards loading into LSB...
                    # So load Byte 4-1 first.. then 6-5.... then 7-8

    # sys.exit("sys exit")


    if(sim_gen == 0):
        for i in range(len(program)):
            # send 2 bytes of address
            if (debug==1):
                print("2 address bytes as being uploaded") 
            x = address[i]  
            x1 = (x&255).to_bytes(1, byteorder='big')   # x&(255=0b11111111) setting other bits other than the 8 LSbs to zero
            x2 = ((x>>8)&255).to_bytes(1, byteorder='big')
            
            if (debug==0):
                ser.write(x1) 
            else:
                # print("x1 =", x1)
                print("x1 =", x1.hex())

            time.sleep(0.001)

            if (debug==0):
                ser.write(x2)
            else:
                # print("x2 =", x2)
                print("x2 =", x2.hex())

            time.sleep(0.001)

            # send 8 bytes of program address 
            if (debug==1):
                print("8 prog data bytes as being uploaded") 
            
            x = int(program[i],16)    # print(int("FF", base=16))  #255 # int() converts the input string whose base we mention, into decimal integer 
            word = program[i]
            x1 = (x&255).to_bytes(1, byteorder='big')   # x&(255=0b11111111) setting other bits other than the 8 LSbs to zero
            x2 = ((x>>8)&255).to_bytes(1, byteorder='big')
            x3 = ((x>>16)&255).to_bytes(1, byteorder='big')
            x4 = ((x>>24)&255).to_bytes(1, byteorder='big')
            x5 = ((x>>32)&255).to_bytes(1, byteorder='big')
            x6 = ((x>>40)&255).to_bytes(1, byteorder='big')
            x7 = ((x>>48)&255).to_bytes(1, byteorder='big')
            x8 = ((x>>56)&255).to_bytes(1, byteorder='big')

            # //  // testing
            # //  // MSB                                                        LSB
            # //   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
            # //   // +--------+----+----+----------------+------------------------+
            # //   // |opcode  | src| dst|          offset|               immediate|
            # //   // +--------+----+----+----------------+------------------------+
            # //   // 63     56   52   48               32                        0

            # if the instruction Dword isn't a starting rule word, current rule end Dword (next rule incoming), last rule end Dword
            if ((word != ("ffffffffffffffff")) and (word != ("ffffffffffffff0f")) and (word != ("fffffffffffffff0"))):
                
                # Program loader loads the first byte in LSB and then move towards loading into LSB...
                    # So load Byte 4-1 first.. then 6-5.... then 7-8

                if (debug==0):
                    ser.write(x4)
                else:
                    # print("x4 =", x4)
                    print("x4 =", x4.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x3)
                else:
                    # print("x3 =", x3)
                    print("x3 =", x3.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x2)
                else:
                    # print("x2 =", x2)
                    print("x2 =", x2.hex())

                time.sleep(0.001)

                if (debug==0):
                    ser.write(x1)
                else:
                    # print("x1 =", x1)
                    print("x1 =", x1.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x6)
                else:
                    # print("x6 =", x6)
                    print("x6 =", x6.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x5)
                else:
                    # print("x5 =", x5)
                    print("x5 =", x5.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x7)
                else:
                    # print("x7 =", x7)
                    print("x7 =", x7.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x8)
                else:
                    # print("x8 =", x8)
                    print("x8 =", x8.hex())
                
                time.sleep(0.001)

                # sys.exit("sys exit")
            
            # else if the instr word is a starting or ending current rule or ending all rules Dword then uploading all bits in order 
            else:

                print(f'word = {word} at i = {i}')

                if (debug==0):
                    ser.write(x1)
                else:
                    # print("x1 =", x1)
                    print("x1 =", x1.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x2)
                else:
                    # print("x2 =", x2)
                    print("x2 =", x2.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x3)
                else:
                    # print("x3 =", x3)
                    print("x3 =", x3.hex())

                time.sleep(0.001)

                if (debug==0):
                    ser.write(x4)
                else:
                    # print("x4 =", x4)
                    print("x4 =", x4.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x5)
                else:
                    # print("x5 =", x5)
                    print("x5 =", x5.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x6)
                else:
                    # print("x6 =", x6)
                    print("x6 =", x6.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x7)
                else:
                    # print("x7 =", x7)
                    print("x7 =", x7.hex())
                
                time.sleep(0.001)
                
                if (debug==0):
                    ser.write(x8)
                else:
                    # print("x8 =", x8)
                    print("x8 =", x8.hex())
                
                time.sleep(0.001)


    # sys.exit("sys exit")

    # print("x_combined is = ",format(x_combined,"08X"))
    #x_combined is =  70326932 , so here the last two extra bytes that werent multiple of 4 bytes i.e., word were left out as well.

    if sim_gen:
        print ("\n\n** Heads up! sim_gen = 1 \n the hex file isn't being uploaded, rather simulation hex file is being generated **\n\n")
        print ("VeBPF prog SIMULATION file creation done")
    else:
        print ("VeBPF prog uploading done")



else:
    sys.exit(f"Please insert correct value of VeBPF_program_loader_version 1 or 2. \nError, exiting.")
