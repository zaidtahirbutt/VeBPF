#!/usr/bin/env python3
"""

Copyright (c) 2023 ZAID TAHIR
Email: zaid.butt.tahir@gmai.com 

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

"""

import logging
import os
import sys
from scapy.all import *
# import glob

# from scapy.layers.l2 import Ether, ARP
# from scapy.layers.inet import IP, UDP

import cocotb_test.simulator

import cocotb
from cocotb.log import SimLog
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.triggers import Timer
from cocotb.wavedrom import trace

# from cocotbext.eth import GmiiFrame, MiiPhy

# test_sim includes
# add search paths seen from project root folder
# (used for vscode test integration)
# sys.path.insert(0, '../../source')
sys.path.insert(0, '../tools/ubpf')
sys.path.insert(0, '../tools')

# add search paths when run from inside test folder
# (used when running test directly)
# sys.path.insert(0, '../../../source')
# sys.path.insert(0, '../../../tools/ubpf')

import unittest
    # the edited unittest_z1 is named as unittest and the original unittest is now unittest_original_version_uncomment_to_use_this cx colour_runner was trying to 
    # import unittest as well.. too many names changes were needed
# import unittest_z1 as unittest
# from '/home/zaidtahir/anaconda3/envs/hbpf_2/lib/python3.7/unittest_z1' import unittest
# from unittest_z1 import *
# from unittest_z1 import unittest as unittest
    # unittest library edited and put in new folder in virt env folder inside python3.7 folder... async and await statements added 
import colour_runner.runner
import os
import gc
import re
import tempfile
import struct
import re
import ntpath
import ubpf.assembler
# import tools.testdata
import testdatatools.testdata
from datetime import datetime
# from migen import *
# from litedram.frontend.bist import LFSR
# from fpga.ram import *
# from fpga.ram64 import *
# from fpga.cpu import *

# importing os module 
import os 
  
# importing shutil module 
import shutil

import time
import asyncio

# ANSI escape codes for formatting
# Text styles
RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
ITALIC = "\033[3m"
UNDERLINE = "\033[4m"
BLINK = "\033[5m"
INVERT = "\033[7m"
HIDDEN = "\033[8m"
STRIKETHROUGH = "\033[9m"

# Foreground colors
BLACK = "\033[30m"
RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"   # Orange-like color
BLUE = "\033[34m"
MAGENTA = "\033[35m"
CYAN = "\033[36m"
WHITE = "\033[37m"

# Bright foreground colors
BRIGHT_BLACK = "\033[90m"
BRIGHT_RED = "\033[91m"
BRIGHT_GREEN = "\033[92m"
BRIGHT_YELLOW = "\033[93m"
BRIGHT_BLUE = "\033[94m"
BRIGHT_MAGENTA = "\033[95m"
BRIGHT_CYAN = "\033[96m"
BRIGHT_WHITE = "\033[97m"

from art import tprint
from termcolor import colored
import io
import contextlib

def big(text, font="block", color="green", bright=True):
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        tprint(text, font=font)
    ascii_art = buffer.getvalue()

    attrs = ["bold"] if bright else []
    for line in ascii_art.splitlines():
        print(colored(line, color, attrs=attrs))

# PGM_DEPTH = "" 
PGM_DEPTH = 4096 
# PGM_DEPTH = None

class AsyncTestCase:
    def __init__(self):
        self.test_results = []

    async def run(self):
        passed = 0
        failed = 0
        errors = 0
        total = 0

        term_width = max(160, shutil.get_terminal_size((160, 20)).columns)
        star_border = "*" * term_width
        backtick_border = "`"

        # Colored boxed ticks and crosses
        def boxed_tick():
            return "\033[92m[✔]\033[0m"  # Green boxed checkmark
        def boxed_cross():
            return "\033[91m[✘]\033[0m"  # Red boxed cross

        # Big emojis for summary
        emoji_pass = "\033[1m\033[92m✅ PASSED\033[0m"   # bright green check mark
        emoji_fail = "\033[1m\033[91m❌ FAILED\033[0m"   # bright red cross
        emoji_stop = "\033[1m\033[91m🛑 ERROR\033[0m"

        # Run tests and print individual results with boxed ticks/crosses
        for name in sorted(dir(self)):
            if name.startswith("test_") and callable(getattr(self, name)):
                method = getattr(self, name)
                total += 1
                try:
                    if asyncio.iscoroutinefunction(method):
                        await method()
                    else:
                        method()
                    passed += 1
                    self.test_results.append((name, "PASS"))
                    print(f" {boxed_tick()} [PASS] {name}")
                except AssertionError as e:
                    failed += 1
                    self.test_results.append((name, f"FAIL: {e}"))
                    print(f" {boxed_cross()} [FAIL] {name}: {e}")
                except Exception as e:
                    errors += 1
                    self.test_results.append((name, f"ERROR: {e}"))
                    print(f" {boxed_cross()} [ERROR] {name}: {e}")

        print("\n")
        big("TEST SUMMARY", font="block", color="light_blue", bright=True)

        print(star_border)
        for name, result in self.test_results:
            symbol = boxed_tick() if result == "PASS" else boxed_cross()
            line = f" {symbol} {name:<40} : {result:>10} "
            print(f"{backtick_border}{line.ljust(term_width-1)}")

        print(star_border)

        # Summary line with big bright emoji, left aligned
        total_line = f"TOTAL: {total}    {emoji_pass}: {passed}    {emoji_fail}: {failed}    {emoji_stop}: {errors}"
        print(f"{backtick_border} {total_line.ljust(term_width-2)}")
        print(star_border + "\n")

        if failed > 0 or errors > 0:
            raise AssertionError(f"{failed} tests failed, {errors} tests errored.")

    # Assertion helpers (unchanged)
    def assertTrue(self, expr, msg=None):
        if not expr:
            raise AssertionError(msg or f"Expected True but got {expr}")

    def assertFalse(self, expr, msg=None):
        if expr:
            raise AssertionError(msg or f"Expected False but got {expr}")

    def assertEqual(self, a, b, msg=None):
        if a != b:
            raise AssertionError(msg or f"{a!r} != {b!r}")

    def assertNotEqual(self, a, b, msg=None):
        if a == b:
            raise AssertionError(msg or f"{a!r} == {b!r}")

    def assertIn(self, item, container, msg=None):
        if item not in container:
            raise AssertionError(msg or f"{item!r} not found in {container!r}")

    def assertIsNone(self, expr, msg=None):
        if expr is not None:
            raise AssertionError(msg or f"Expected None but got {expr!r}")

    def assertLessEqual(self, a, b, msg=None):
        if not a <= b:
            raise AssertionError(msg or f"Expected {a!r} <= {b!r}")


def str_to_int_padded(s, length=256):
    # Encode string to ASCII bytes
    b = s.encode('ascii')
    # Trim or pad with zeros to exact length
    b = b[:length] + b'\x00' * max(0, length - len(b))
    # Convert to int
    return int.from_bytes(b, 'big')

def int_to_str_padded(i, length=256):
    b = i.to_bytes(length, 'big')
    # Strip trailing zeros
    b = b.rstrip(b'\x00')
    return b.decode('ascii')


# class TestFPGA_Sim(unittest.TestCase):
class TestFPGA_Sim(AsyncTestCase):
    dbg_pgm_mem = []
    test_var1 = []
    pgm_LE_DW_list_VerilgEbpf = []
    tb = None  # can use both type of references, self.tb and TestFPGA_Sim.tb
        # Class variable: Shouldnt be defined in __init__ method if inteded to be used as class variable
        # https://pynative.com/python-class-variables/#:~:text=of%20Class%20Variables-,What%20is%20an%20Class%20Variable%20in%20Python%3F,all%20instances%20of%20a%20class.
            # can use both type of references, self.tb and TestFPGA_Sim.tb
    iteration = 0
    # iteration = None  # was able to use self.iteration after it was declared as None.. needed to modify it outside the object then?
        # maybe I used iteration = 0 and not None thats why I could reference it as class variable using self.iteration?
    # def __init__ (self, tb):
    #     self.tb = tb
    # flag_test_branch_VeBPF_DISL_Integration_v2_multi_VeBPFs_Rules = 0
    # flag_test_branch_VeBPF_DISL_Integration_v2_multi_VeBPFs_Rules_multiRuleTesting = 0
    flag_reprog_test = 0
    flag_dump_sim_waveform = 0
    instruction_pointer_next_VeBPF_rule = 0  
        # this stayed 0, maybe I needed to do TestFPGA_Sim.instruction_pointer_next_VeBPF_rule = updated value
    instruction_pointer_next_VeBPF_rule_end = 0


    # async def initialize_cocotb_tb(self, tb):
        # self.tb = tb
        # tb = tb

    async def random_stuff_test(self): # ERROR still there # doesnt seem to run # ERROR RESOLVED by adding async # ERROR   Failed to import module test_cpu: 'await' outside async function (test_cpu.py, line 95)        
        print("\n ***************Inside TestFPGA_Sim.random_stuff_test() ############# *******************\n")

        print("Inside TestFPGA_Sim ==> 1 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
        print("Inside TestFPGA_Sim ==> 1 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)

        await RisingEdge(self.tb.dut.clk)
        await RisingEdge(self.tb.dut.clk)

        self.tb.dut.reset_n.setimmediatevalue(1)
        self.tb.dut.csr_ctl.setimmediatevalue(1)

        await RisingEdge(self.tb.dut.clk)
        await RisingEdge(self.tb.dut.clk)

        # print("Inside TestFPGA_Sim ==> 2 self.tb.dut.reset_n.value = ", TestFPGA_Sim.tb.dut.reset_n.value)
        # print("Inside TestFPGA_Sim ==> 2 self.tb.dut.csr_ctl.value = ", TestFPGA_Sim.tb.dut.csr_ctl.value)
            # can use both type of references, self.tb and TestFPGA_Sim.tb

        print("Inside TestFPGA_Sim ==> 2 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
        print("Inside TestFPGA_Sim ==> 2 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)
        print("\n ***************############# *******************\n")

        # print("\n ***************############# \n")
    

    # def check_datafile(self, filename): # ERROR: SyntaxError: 'await' outside async function
    # async def check_datafile(self, filename): 
        # ERROR: /home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/test_cpu.py:684: RuntimeWarning: coroutine 'TestFPGA_Sim.check_datafile' was never awaited
        # suite._tests[0].check_datafile(dummy1)
        # RuntimeWarning: Enable tracemalloc to get the object allocation traceback


    async def random_stuff_test2(self): # ERROR still there # doesnt seem to run # ERROR RESOLVED by adding async # ERROR   Failed to import module test_cpu: 'await' outside async function (test_cpu.py, line 95)        
        
        print("\n ***************Inside TestFPGA_Sim.check_datafile().random_stuff_test2() ############# *******************\n")

        print("Inside TestFPGA_Sim ==> 1 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
        print("Inside TestFPGA_Sim ==> 1 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)

        await RisingEdge(self.tb.dut.clk)
        await RisingEdge(self.tb.dut.clk)
        # ERROR: SyntaxError: 'await' outside async function

        self.tb.dut.reset_n.setimmediatevalue(0)
        self.tb.dut.csr_ctl.setimmediatevalue(0)

        await RisingEdge(self.tb.dut.clk)
        await RisingEdge(self.tb.dut.clk)

        print("Inside TestFPGA_Sim ==> 2 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
        print("Inside TestFPGA_Sim ==> 2 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)
        
        await RisingEdge(self.tb.dut.clk)
        await RisingEdge(self.tb.dut.clk)

        self.tb.dut.reset_n.setimmediatevalue(1)
        self.tb.dut.csr_ctl.setimmediatevalue(1)

        await RisingEdge(self.tb.dut.clk)
        await RisingEdge(self.tb.dut.clk)

        print("Inside TestFPGA_Sim ==> 2 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
        print("Inside TestFPGA_Sim ==> 2 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)

        print("\n ***************############# *******************\n")
    

    async def check_datafile(self, filename):  # comment this cx async check_datafile isnt working OR maybe I'll edit the whole unittest library (:)
    # def check_datafile(self, filename):
        """
        Given assembly source code and an expected result, run the eBPF program and
        verify that the result matches.
        """

        print("\n\n awaiting self.random_stuff_test2()")
        # self.random_stuff_test3()

        # yield self.random_stuff_test2()
        
        await self.random_stuff_test2()
            # Still getting ERROR: test_cpu.TestFPGA_Sim
            # test_jeq-imm_z1 ... /home/zaidtahir/anaconda3/envs/hbpf_2/lib/python3.7/unittest/case.py:628: RuntimeWarning: coroutine 'generate_testcase.<locals>.test' was never awaited
            # testMethod()
            # RuntimeWarning: Enable tracemalloc to get the object allocation traceback
            # ok

        
        # self.random_stuff_test2()
            # ERROR: /home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/test_cpu.py:163: RuntimeWarning: coroutine 'TestFPGA_Sim.random_stuff_test2' was never awaited
            # self.random_stuff_test2()
            # RuntimeWarning: Enable tracemalloc to get the object allocation traceback
                # searching for RuntimeWarning (ctrl F)
            # Also error in main test method, test_cpu.TestFPGA_Sim
            # test_jeq-imm_z1 ... /home/zaidtahir/anaconda3/envs/hbpf_2/lib/python3.7/unittest/case.py:628: RuntimeWarning: coroutine 'generate_testcase.<locals>.test' was never awaited
            # testMethod()
            # RuntimeWarning: Enable tracemalloc to get the object allocation traceback
            # ok



        # deleting self.random_stuff_test2() code from here

        ##################### resetting verilog-eBPF cpu pgm memory before each test suite is executed #######################
        # Setting reset HIGH for V-eBPF
        self.tb.dut.reset_n.setimmediatevalue(0)
        self.tb.dut.csr_ctl.setimmediatevalue(0)

        # if (TestFPGA_Sim.flag_test_branch_VeBPF_DISL_Integration_v2_multi_VeBPFs_Rules):
        # print("\n\nTesting the branch VeBPF_DISL_Integration_v2_multi_VeBPFs_Rules during this run\n\n")
        # Setting reset for pgm also HIGH for V-eBPF
        self.tb.dut.VeBPF_prog_reset_in.setimmediatevalue(1)
        self.tb.dut.VeBPF_prog_write_enable_in.setimmediatevalue(0)
            
        await RisingEdge(self.tb.dut.clk)
        await RisingEdge(self.tb.dut.clk)
        print("Inside check_datafile ==> self.tb.dut.VEBPF_SIM = ", self.tb.dut.VEBPF_SIM)
        print("Inside check_datafile ==> self.tb.dut.SIMULATION = ", self.tb.dut.SIMULATION)
        print("Inside check_datafile ==> 2 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
        print("Inside check_datafile ==> 2 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)

        # updating PGM_DEPTH to what the parameter value of PGM_DEPTH is in VeBPF cpu pgm mem
        
        PGM_DEPTH = self.tb.dut.pgm.MEMORY_DEPTH.value
        # PGM_DEPTH = self.tb.dut.pgm.MEMORY_DEPTH
            # when there was no .value, this error was popping up # TypeError: 'ConstantObject' object cannot be interpreted as an integer


        print(f'\n\nPGM_DEPTH = {PGM_DEPTH}\n\n')

        # sys.exit("HELLO")

        # need to reset and then load pgm mem in V-eBPF while it is in reset state, then set RESET to LOW to start the V-eBPF
        for idx in range(PGM_DEPTH):
            self.tb.dut.pgm.mem[idx].value = 0

        await RisingEdge(self.tb.dut.clk)


        # print()
        # sys.exit(f"HELLO filename = {filename}")
        print(f"HELLO filename = {filename}")
        td = testdatatools.testdata.read(filename)
        # sys.exit("HELLO")
        td['filename'] = filename
        td['name'] = os.path.splitext(os.path.split(filename)[1])[0]

        self.assertFalse('asm' not in td and 'raw' not in td,
                    'no asm or raw section in datafile')
        # sys.exit("HELLO")
        #self.assertFalse('result' not in td and 'error' not in td and 'error pattern' not in td,
        #            'no result or error section in datafile')

        # Prepare program memory
        if 'raw' in td:
            code = b''.join(struct.pack('>Q', x) for x in td['raw'])
        else:
            code = ubpf.assembler.assemble(td['asm'])
            td['raw'] = code

        # // print assembly code
        # print("----- z Assembly code -----")
        # print(td['asm'])
            # throwing error for RAW code 

        half_words = len(code) // 4
        pgm_mem = list(struct.unpack('>{}L'.format(half_words), code))  # = means we use native endian to unpack
        # endian in ubuntu is little endian thats why the code unpacked in little endian and the VM here runs on little endian as well
            # lscpu | grep Endian
            # Byte Order:                      Little Endian

        # // print code td['raw'] vs pgm_mem
        print("\n \n print code td['raw'] vs pgm_mem \n \n")
        print("\n \n print code td['raw'] \n \n")
        print(td['raw'])
        # print("\n \n print code pgm_mem \n \n")
        # print(pgm_mem)
        # print("\n \n")

        print("\n \n print code code \n \n")
        print(code)
        print("\n \n")


        # print("\n \n print code pgm_mem \n \n")
        # # print(pgm_mem)
        # for x in pgm_mem:
        #     print(hex(x))
        #     # print(x)
        # print("\n \n")

        # Dump program memory for debug.
        print("----- Program memory -----")
        words = len(code) // 8
        print("len(code) = ", len(code))
        print("words", words)
            # len(code) =  64   # 64 bytes
            # words 8           # 8 64-bit DWs
            # so code is in form of bytes

        pgm_bytes_len = len(code)  # 64 bytes i.e., 64 bytes x 8 bits/byte 

        # print("printing byte code[12] in hex = ", hex(code[12]))
        # print("printing byte code[12] in bytes = ", code[12].to_bytes(length=1, byteorder='big').hex())    
        #     # int.to_bytes(length=1, byteorder='big', *, signed=False)¶

        dbg_pgm_mem = list(struct.unpack('>{}Q'.format(words), code))
            # https://docs.python.org/3/library/struct.html#struct-alignment
            # Format    C Type                  Python type     Standard size
            # Q         unsigned long long      integer             8
            # B         unsigned char           integer             1

        self.dbg_pgm_mem = dbg_pgm_mem
        # TestFPGA_Sim.dbg_pgm_mem = dbg_pgm_mem
        self.test_var1 = dbg_pgm_mem

        dbg_pgm_mem_BYTES = list(struct.unpack('>{}B'.format(pgm_bytes_len), code))

        
        # print("\n \n print code dbg_pgm_mem \n \n")
        # for x in dbg_pgm_mem:
        #     print(hex(x))
            # print(x)
            # machine_instruction_64bit_DW.append()
        # print(dbg_pgm_mem)
        # print("\n \n")

        # print("\n \n print code dbg_pgm_mem_BYTES \n \n")
        # for x in dbg_pgm_mem_BYTES:
        #     print(hex(x))  # output same as for loop output of printing code below

        # print("\n \n print code code using for loop \n \n")
        counter_pgm_DWbytes = 0
        counter_pgm_DWs = 0
        machine_instruction_64bit_DW = [0] * 8   # init array
        pgm_DW_rearranged_For_VerilgEbpf = [0] * 8   # init array
        pgm_LE_DW_list_VerilgEbpf = []
        
        for code_byte in code:
            # print(hex(code_byte))
            
            machine_instruction_64bit_DW[counter_pgm_DWbytes] = code_byte
            
            counter_pgm_DWbytes = counter_pgm_DWbytes + 1
            
            if (counter_pgm_DWbytes == 8):  # bytes counter 0 till 7 appended
                counter_pgm_DWs = counter_pgm_DWs + 1
                
                pgm_DW_rearranged_For_VerilgEbpf[0] = machine_instruction_64bit_DW[0]  # so this (64_dw idx 0 i.e., byte 8) is VerilgEbpf idx 0 i.e., Byte 8 MSB for VeBPF instruction below (MSB is byte 8 and LSB is byte 1)
                pgm_DW_rearranged_For_VerilgEbpf[1] = machine_instruction_64bit_DW[1]  # so this (64_dw idx 1 i.e., byte 7) is VerilgEbpf idx 1 i.e.Byte 7 for VeBPF instruction below 
                # flipping for Byte 5-6 below
                pgm_DW_rearranged_For_VerilgEbpf[2] = machine_instruction_64bit_DW[3]  # so this (64_dw idx 3 i.e., byte 5) is VerilgEbpf idx 2 i.e. Byte 6 for VeBPF instruction below
                pgm_DW_rearranged_For_VerilgEbpf[3] = machine_instruction_64bit_DW[2]  # so this (64_dw idx 2 i.e., byte 6) is VerilgEbpf idx 3 i.e. Byte 5 for VeBPF instruction below
                # flipping for Byte 1-4 below
                pgm_DW_rearranged_For_VerilgEbpf[4] = machine_instruction_64bit_DW[7]  # so this (64_dw idx 7 i.e., byte 1) is VerilgEbpf idx 4 i.e. Byte 4 for VeBPF instruction below
                pgm_DW_rearranged_For_VerilgEbpf[5] = machine_instruction_64bit_DW[6]  # so this (64_dw idx 6 i.e., byte 2) is VerilgEbpf idx 5 i.e. Byte 3 for VeBPF instruction below 
                pgm_DW_rearranged_For_VerilgEbpf[6] = machine_instruction_64bit_DW[5]  # so this (64_dw idx 5 i.e., byte 3) is VerilgEbpf idx 6 i.e. Byte 2 for VeBPF instruction below
                pgm_DW_rearranged_For_VerilgEbpf[7] = machine_instruction_64bit_DW[4]  # so this (64_dw idx 4 i.e., byte 4) is VerilgEbpf idx 7 i.e. Byte 1 for VeBPF instruction below
                
                    # // MSB                                                        LSB
                    # //   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
                    # //   // +--------+----+----+----------------+------------------------+
                    # //   // |opcode  | src| dst|          offset|               immediate|
                    # //   // +--------+----+----+----------------+------------------------+
                    # //   // 63     56   52   48               32 
                    # mem [0] = {8'h7a, 8'h01, 16'h0002, 32'h44332211};  // byte 1 - 4 means these bytes are flipped: L.E => 11223344 becomes -> 44332211 // same for other instruction op codes
                    
                    # example instruction below:
                    # 0x7a01020011223344
                    # mem [0] = {8'h7a, 8'h01, 16'h0002, 32'h44332211};  // byte 1 - 4 means these bytes are flipped: L.E => 11223344 becomes -> 44332211 // same for other instruction op codes
                        # 0x7a is machine_instruction_64bit_DW[0] and pgm_DW_rearranged_For_VerilgEbpf[0] and Byte 8 MSB for VeBPF instruction

                counter_pgm_DWbytes = 0  #reset counter
                
                # pgm_LE_DW_list_VerilgEbpf.append(pgm_DW_rearranged_For_VerilgEbpf)
                    # https://stackoverflow.com/questions/42955147/append-is-overwriting-existing-data-in-list
                        # append was causing the overwrite of all list elements by last element of list in stack, by reference, hence .copy() is used
                pgm_LE_DW_list_VerilgEbpf.append(pgm_DW_rearranged_For_VerilgEbpf.copy())
                
                # print("pgm_LE_DW_list_VerilgEbpf ",  pgm_LE_DW_list_VerilgEbpf[counter_pgm_DWs-1])
                
                # for pgm_DW_INDEX in range((len(pgm_LE_DW_list_VerilgEbpf))):
                #     # print("pgm_LE_DW_list_VerilgEbpf ",  " ".join(hex(x) for x in pgm_LE_DW_list_VerilgEbpf[pgm_DW_INDEX]),end="   ")
                #     print("pgm_LE_DW_list_VerilgEbpf ",  " ".join(hex(x) for x in pgm_LE_DW_list_VerilgEbpf[pgm_DW_INDEX]))


                # if (counter_pgm_DWs == 3):
                #     print("pgm_DW_rearranged_For_VerilgEbpf = ", " ".join(hex(x) for x in pgm_DW_rearranged_For_VerilgEbpf))               
                    
                #     sys.exit()
        print("\n \n *********  print pgm_LE_DW_list_VerilgEbpf ***** \n \n")
        DW_count = 0
        for DW in pgm_LE_DW_list_VerilgEbpf:
            # print("Printing each byte in list of pgm_LE_DW_list_VerilgEbpf = ", DW.hex())
            print("\n pgm_LE_DW_list_VerilgEbpf[%d] = " % DW_count, end= "")
            for byte in DW:
                print(hex(byte), end=",  ")
            DW_count = DW_count + 1

        self.pgm_LE_DW_list_VerilgEbpf = pgm_LE_DW_list_VerilgEbpf
        # self.pgm_LE_DW_list_VerilgEbpf means for each class object there can be separate pgm mem

        print("\n \n print code dbg_pgm_mem \n \n")
        for i, opc in enumerate(dbg_pgm_mem):
           print("%04d: %016x" % (i, opc))

        print("\n\n Preparing data memory \n \n")

        # Prepare data memory
        data_mem = td.get('mem')
        data_mem_flag = 0
        if isinstance(data_mem, bytes):
            data_mem = list(data_mem)
            data_mem_flag = 1

        # first initialize all data_memory to 0 
        data_mem_depth = self.tb.dut.data_mem.MEMORY_DEPTH  # parameters can be accessed this way 
        
        print(f'\ndata_mem_depth = {data_mem_depth} \n')
        
        for i in range(int(data_mem_depth)):
            self.tb.dut.data_mem.mem[i].value = 0

        await RisingEdge(self.tb.dut.clk)

        if (data_mem_flag):
            for i, data in enumerate(data_mem):
                print(f'data_mem[{i}] = {hex(data)}')
                self.tb.dut.data_mem.mem[i].value = data
        else:
            print("\n No data_mem on initialization \n")

        await RisingEdge(self.tb.dut.clk)

        if(data_mem_flag):
            for i, data in enumerate(data_mem):
                print(f'self.tb.dut.data_mem.mem[{i}] = {hex(self.tb.dut.data_mem.mem[i].value)}')


        # Inserting pgm memory in V-eBPF cpuz pgm memory 
        # sys.exit("Manually exiting")
        print("\n Setting debug = 1 for the verilog dump module \n")
        vcd_file = os.path.abspath(os.path.dirname(filename))
        vcd_file = os.path.join(vcd_file, (td['name'] + "_VeBPF" + ".fst"))
        sim_fst_file_name_only = td['name'] + ".fst"
        print("\n vcd file name = ", vcd_file)
            #  vcd file name =  /home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/data9_DISL_eBPF/jge-imm.fst
        
        print("\n sim_fst.fst file name = ", sim_fst_file_name_only)
        
        # Lets test if adding full path as filename works
        simulation_dump_name = vcd_file
        
        # sys.exit("Manually exiting")

        # converting the dump .fst file name to int and passing it to the dump sv module so it can print a .fst file with that name after converting that int back to string..
        int_value_of_file_name = int.from_bytes(simulation_dump_name.encode('utf-8'), byteorder='big', signed=False)
        self.tb.dut.dump_file_module.my_string.value = int_value_of_file_name
        # self.tb.dut.dump_file_module.my_string.value = int.from_bytes("Testing123.fst".encode('utf-8'), byteorder='big', signed=False)

        # *************************************************************************
        # ************* IMP: Enable Waveform Output ******************************* => debug flag to start tracing simulation waveform, comment out if dont want sim waveform
        self.tb.dut.dump_file_module.debug_flag.value = TestFPGA_Sim.flag_dump_sim_waveform


        # Re-arranging the program memory so each eBPF machine instruction comes out as a 64 bit DW, arranged
        # w.r.t what our eBPF cpu requires it to be, for testing and updating program memory here 
        DW_count = 0
        pgm_DW = 0
        byte_count = 0
        for DW in pgm_LE_DW_list_VerilgEbpf:
            byte_count = 0
            pgm_DW = 0
            for byte in DW:
                if (byte_count == 0):
                    pgm_DW = byte
                else:
                    pgm_DW = (pgm_DW << 8) + byte
                # dut.pgm.mem[DW_count][(byte_count*8):(((byte_count*8)+8)-1)] = byte  
                    # ERROR: IndexError: Slice indexing is not supported
                byte_count = byte_count + 1
            self.tb.dut.pgm.mem[DW_count] = pgm_DW
            DW_count = DW_count + 1

        await RisingEdge(self.tb.dut.clk)

        # the instruction pointer value for the next VeBPF rule
        instruction_pointer_next_VeBPF_rule = DW_count
        TestFPGA_Sim.instruction_pointer_next_VeBPF_rule = instruction_pointer_next_VeBPF_rule
            # needed to do this above cx I guess just using instruction_pointer_next_VeBPF_rule 
            # was initializing instruction_pointer_next_VeBPF_rule as an object member instead of
            # class varibale,, but now with TestFPGA_Sim.instruction_pointer_next_VeBPF_rule, the 
            # class variable instruction_pointer_next_VeBPF_rule will be updated

        # Setting up pgm mem and data mem for the next VeBPF Rule if flag is active
        if (TestFPGA_Sim.flag_reprog_test):
            print("\nMulti-rule testing is active\n")   
            print(f'\n\nLoading next VeBPF Rule into pgm mem starting at Instruction pointer (IP) = {instruction_pointer_next_VeBPF_rule} \n\n')

            # Setting DW_count to next IP
            DW_count = instruction_pointer_next_VeBPF_rule
            pgm_DW = 0
            byte_count = 0
            for DW in pgm_LE_DW_list_VerilgEbpf:
                byte_count = 0
                pgm_DW = 0
                for byte in DW:
                    if (byte_count == 0):
                        pgm_DW = byte
                    else:
                        pgm_DW = (pgm_DW << 8) + byte
                    # dut.pgm.mem[DW_count][(byte_count*8):(((byte_count*8)+8)-1)] = byte  
                        # ERROR: IndexError: Slice indexing is not supported
                    byte_count = byte_count + 1
                self.tb.dut.pgm.mem[DW_count] = pgm_DW
                DW_count = DW_count + 1

            instruction_pointer_next_VeBPF_rule_end = DW_count  # or does this need to be subtracted by 1?
            TestFPGA_Sim.instruction_pointer_next_VeBPF_rule_end = instruction_pointer_next_VeBPF_rule_end

            print("\n\n Preparing data memory for running the same pgm mem one more time \n \n")

            # Prepare data memory
            data_mem = td.get('mem')
            data_mem_flag = 0
            if isinstance(data_mem, bytes):
                data_mem = list(data_mem)
                data_mem_flag = 1

            # first initialize all data_memory to 0 
            data_mem_depth = self.tb.dut.data_mem.MEMORY_DEPTH  # parameters can be accessed this way 
            
            print(f'\ndata_mem_depth = {data_mem_depth} \n')
            
            for i in range(int(data_mem_depth)):
                self.tb.dut.data_mem.mem[i].value = 0

            await RisingEdge(self.tb.dut.clk)

            if (data_mem_flag):
                for i, data in enumerate(data_mem):
                    print(f'data_mem[{i}] = {hex(data)}')
                    self.tb.dut.data_mem.mem[i].value = data
            else:
                print("\n No data_mem on initialization \n")

            await RisingEdge(self.tb.dut.clk)

            if(data_mem_flag):
                for i, data in enumerate(data_mem):
                    print(f'self.tb.dut.data_mem.mem[{i}] = {hex(self.tb.dut.data_mem.mem[i].value)}')


        # dut.pgm.mem[1] = 0xb40700000a000000

        await RisingEdge(self.tb.dut.clk)

        print("Inside check_datafile ==>  dut.pgm.mem[1] = ", hex(self.tb.dut.pgm.mem[1].value))

        DW_count = 0
        for DW in pgm_LE_DW_list_VerilgEbpf:
            print(f'For loop After updating thru unittest ==> dut.pgm.mem[{DW_count}] = {hex(self.tb.dut.pgm.mem[DW_count].value)}')
            # print("For loop After updating thru Inside check_datafile ==> dut.pgm.mem[] = ", hex(self.tb.dut.pgm.mem[DW_count].value))
            DW_count = DW_count + 1
            # After updating thru unittest ==> dut.pgm.mem[1] =  0xb40700000000000a

        # print out pgm mem for the next VeBPF Rule if flag is active
        if (TestFPGA_Sim.flag_reprog_test):
            print("\nPrint next VeBPF rule prog memory\n")
            for i in range(instruction_pointer_next_VeBPF_rule, instruction_pointer_next_VeBPF_rule_end):
                print(f'For loop After updating thru unittest ==> dut.pgm.mem[{i}] = {hex(self.tb.dut.pgm.mem[i].value)}')

        

        for k in range(10):
                await RisingEdge(self.tb.dut.clk)


        print("Inside check_datafile ==> self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
        print("Inside check_datafile ==> self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)
        


        print(" RUNNING V_eBPF_cpu_test inside check_datafile")

        if (TestFPGA_Sim.flag_reprog_test):
            # testing reprogram capability while the VeBPF cpu is in RESET state for branch branch_VeBPF_DISL_Integration_v2_multi_VeBPFs_Rules after pre_21Sept2023
            print(f"{BOLD}{BLUE}Reprogramming feature of VeBPF is being tested in this test suite{RESET}")

            # already being set in V_eBPF_cpu_test() in the reprog part
            # self.tb.dut.run_next_selected_rule_en.value = 1
            # self.tb.dut.ip_next_rule.value = instruction_pointer_next_VeBPF_rule

            await RisingEdge(self.tb.dut.clk)

        await self.V_eBPF_cpu_test(test_data = td)
        print("******************* self.iteration = ", TestFPGA_Sim.iteration)

    # async def V_eBPF_cpu_test(self, cpu, test_data, default_max_clock_cycles=1000):
    async def V_eBPF_cpu_test(self, test_data, default_max_clock_cycles=1000):
    # async def V_eBPF_cpu_test(self, test_data, default_max_clock_cycles=1000+10000):  # max clock cycles increased # didnt need to increase the max clock cycles
        """
        Perform actual test, control CPU signals like clock etc.
        """
        print(f"{BOLD}{BRIGHT_YELLOW}Running VeBPF test{RESET}")

        clk_cnt = 0

        # Prepare result to check
        result = None
        if 'result' in test_data:
            result = int(test_data['result'], 0)
            # overwriting this test case z
            # result = 0

        expected_error = 0
        expected_error_msg = None
        if 'error' in test_data:
            expected_error = 1
            expected_error_msg = test_data['error']

        expected = dict(re.findall(r'(\S+)\s*=\s*(".*?"|\S+)', test_data.get('expected', '')))
        #print(expected)
        expected_halt = 1 if int(expected.get('halt', '1'), 0) > 0 else 0
        # this can override error section above
        expected_error = 1 if int(expected.get('error', str(expected_error)), 0) > 0 else 0
        # overwriting above z
        # expected_error = 1

        max_clock_cycles = int(expected.get('clocks', str(default_max_clock_cycles)), 0)
        disable_test = int(expected.get('disable_sim_test', str("0")))

        if disable_test == 1:
            self.skipTest("Testcase not available for Simulator test")

        # Start with 5 clocks in reset.
        
        # yield cpu.reset_n.eq(0)
        self.tb.dut.reset_n.value = 0  # RESET HIGH

        
        for i in range(5):
            # yield
            await RisingEdge(self.tb.dut.clk)

        # set r1 - r5 input arguments
        args = test_data.get('args', {})
        r1 = int(str(args.get('r1', 0)), 0)
        r2 = int(str(args.get('r2', 0)), 0)
        r3 = int(str(args.get('r3', 0)), 0)
        r4 = int(str(args.get('r4', 0)), 0)
        r5 = int(str(args.get('r5', 0)), 0)
        # yield cpu.csr_r1.storage.eq(r1)
        # yield cpu.csr_r2.storage.eq(r2)
        # yield cpu.csr_r3.storage.eq(r3)
        # yield cpu.csr_r4.storage.eq(r4)
        # yield cpu.csr_r5.storage.eq(r5)
        # yield

        self.tb.dut.r1.value = r1
        self.tb.dut.r2.value = r2
        self.tb.dut.r3.value = r3
        self.tb.dut.r4.value = r4
        self.tb.dut.r5.value = r5
        await RisingEdge(self.tb.dut.clk)

        print("Input:")
        print("R1: ({:20}, 0x{:016x}), R2: ({:20}, 0x{:016x})".format(r1, r1, r2, r2))
        print("R3: ({:20}, 0x{:016x}), R4: ({:20}, 0x{:016x})".format(r3, r3, r4, r4))
        print("R5: ({:20}, 0x{:016x})".format(r5, r5))

        # Open op-code statistics file
        test_file = test_data.get("filename", None)
        stat_file = None
        if test_file is not None:
            stat_file = os.path.splitext(test_file)[0] + ".stats"
            sfd = open(stat_file, "a")

        # End reset.
        self.tb.dut.reset_n.value = 1  # RESET LOW
        
        if (TestFPGA_Sim.flag_reprog_test):
            # testing reprogram capability while the VeBPF cpu is in RESET state for branch branch_VeBPF_DISL_Integration_v2_multi_VeBPFs_Rules after pre_21Sept2023
            self.tb.dut.run_next_selected_rule_en.value = 0
        
        # if (TestFPGA_Sim.flag_test_branch_VeBPF_DISL_Integration_v2_multi_VeBPFs_Rules):
        print("\n\nSetting reset VeBPF_prog_reset_in to LOW in method async def V_eBPF_cpu_test() for branch testing VeBPF_DISL_Integration_v2_multi_VeBPFs_Rules\n\n")
        # Setting reset for pgm also LOW for V-eBPF
        self.tb.dut.VeBPF_prog_reset_in.value = 0

        await RisingEdge(self.tb.dut.clk)
        # yield cpu.reset_n.eq(1)
        # yield


        # Clock CPU until halt, error or max clock cycles reached.
        # halt = (yield cpu.halt)
        # error = (yield cpu.error)
        # r0 = (yield cpu.r0)

        halt = self.tb.dut.halt.value
        error = self.tb.dut.error.value
        r0 = self.tb.dut.r0.value



        while halt == 0 and clk_cnt <= max_clock_cycles:
            # break while loop when halt = 1 means our ebpf cpu finihsed processing
            # or the max clk cycles have been reached 
            
            halt = self.tb.dut.halt.value
            error = self.tb.dut.error.value
            r0 = self.tb.dut.r0.value
            r6 = self.tb.dut.r6.value 
            r7 = self.tb.dut.r7.value
            r8 = self.tb.dut.r8.value 
            r9 = self.tb.dut.r9.value
            r10 = self.tb.dut.r10.value 
            await RisingEdge(self.tb.dut.clk)
            
            # halt = (yield cpu.halt)
            # error = (yield cpu.error)
            # r0 = (yield cpu.r0)
            # r6 = (yield cpu.r6)
            # r7 = (yield cpu.r7)
            # r8 = (yield cpu.r8)
            # r9 = (yield cpu.r9)
            # r10 = (yield cpu.r10)
            # yield
            
            if not halt: # means halt is 0
                clk_cnt += 1

        print("Output:")
        if result is None:
            # print("Clock cycles: ({}), halt: ({}), error: ({}), R0: ({:20}, 0x{:016x})".format(
            print("Clock cycles: ({}), halt: ({}), error: ({}), R0: (b'{}, d'{}, {})".format(
                clk_cnt,
                "LOW" if halt == 0 else "HIGH",
                # "LOW" if error == 0 else "HIGH", r0, r0))
                "LOW" if error == 0 else "HIGH", r0, int(r0), hex(r0)))

            # Error
            # print("Clock cycles: ({}), halt: ({}), error: ({}), R0: (b'{}, d'{}, 0x{}), expected R0: (d'{}, 0x{})".format(
            #     clk_cnt,
            #     "LOW" if halt == 0 else "HIGH",
            #     # "LOW" if error == 0 else "HIGH", r0, r0))
            #     "LOW" if error == 0 else "HIGH", r0, int(r0), hex(r0), result, hex(result)))

        else:
            print("Clock cycles: ({}), halt: ({}), error: ({}), R0: (b'{}, d'{}, {}), expected R0: (d'{}, {})".format(
                clk_cnt,
                "LOW" if halt == 0 else "HIGH",
                # "LOW" if error == 0 else "HIGH", r0, r0))
                "LOW" if error == 0 else "HIGH", r0, int(r0), hex(r0), result, hex(result)))



        # print("R6: ({:20}, 0x{:016x}), R7: ({:20}, 0x{:016x})".format(r6, r6, r7, r7))
        print("R6: ({}, {}), R7: ({}, {})".format(r6, hex(r6), r7, hex(r7)))

        # print("R8: ({:20}, 0x{:016x}), R9: ({:20}, 0x{:016x})".format(r8, r8, r9, r9))
        print("R8: ({}, {}), R9: ({}, {})".format(r8, hex(r8), r9, hex(r9)))
        
        # print("R10:({:20}, 0x{:016x})".format(r10, r10))
        print("R10:({}, {})".format(r10, hex(r10)))

        # Write clock cycles for this test to statistics file
        if stat_file is not None:
            do_graph = int(str(args.get('graph', 1)), 0)
            do_graph = 1 if do_graph > 0 else 0
            date = datetime.now().strftime("%Y%m%d-%H%M%S")
            sfd.write("\"SIM\",\"{}\",{},{},{},{}\n".format(date, clk_cnt, halt, error, do_graph))
            sfd.close()

        # Check result
        #if not expected_error:
        #    self.assertEqual(error, 0,
        #        "Action completes with error signal HIGH")
        #else:
        #    self.assertEqual(error, 1,
        #        "Action expected to complete with error signal HIGH but was LOW")
        #    if error_expected_msg is not None:
        #        print("Expected error: {}".format(error_expected_msg))
        #    return

        self.assertEqual(error, expected_error,
            ("Action does not complete with expected error signal level; " +
                "was {} should be {}").format(error, expected_error))

        self.assertLessEqual(clk_cnt, max_clock_cycles,
            "Action did not complete within max clock cycles ({})".format(
                max_clock_cycles))

        self.assertEqual(halt, expected_halt,
            ("Action does not complete with expected halt signal level; " +
                "was {} should be {}").format(halt, expected_halt))

        # if result is not None:
        #     self.assertEqual(r0, result,
        #         ("Received result ({}, 0x{:08x}) not equal expected " +
        #         "({}, 0x{:08x})").format(
        #             r0, r0, result, result))

        if result is not None:
            self.assertEqual(r0, result,
                ("Received result (b'{}, d'{}, {}) not equal expected " +
                "(d'{}, {})").format(
                    r0, int(r0), hex(r0), result, hex(result)))
        print(f"Reprog flag TestFPGA_Sim.flag_reprog_test = {TestFPGA_Sim.flag_reprog_test}")
        big("Test Completed")

        # Run the next VeBPF rule when Multi Rule testing is active according to current branch
        if (TestFPGA_Sim.flag_reprog_test):
            print(f"{BOLD}{BRIGHT_BLUE}Reprogramming VeBPF{RESET}")
            # checking if VeBPF cpu has halted
            if (self.tb.dut.halt.value):
                print("\n!!!!!!!!!!!! ********* VeBPF has been halted. Setting the ip_next to the next VeBPF rule stored in pgm mem of VeBPF ***** !!!!!!!!!!!!!!\n")

                # Start with 5 clocks in reset.
        
            # yield cpu.reset_n.eq(0)
            self.tb.dut.reset_n.value = 0  # RESET HIGH

            
            for i in range(5):
                # yield
                await RisingEdge(self.tb.dut.clk)

            self.tb.dut.run_next_selected_rule_en.value = 1
            self.tb.dut.ip_next_rule.value = TestFPGA_Sim.instruction_pointer_next_VeBPF_rule
            print(f"{BOLD}{BRIGHT_CYAN}VeBPF reprogrammed with its instruction pointer now starting at {hex(TestFPGA_Sim.instruction_pointer_next_VeBPF_rule)} for this next eBPF program{RESET}")

            # set r1 - r5 input arguments
            args = test_data.get('args', {})
            r1 = int(str(args.get('r1', 0)), 0)
            r2 = int(str(args.get('r2', 0)), 0)
            r3 = int(str(args.get('r3', 0)), 0)
            r4 = int(str(args.get('r4', 0)), 0)
            r5 = int(str(args.get('r5', 0)), 0)
            # yield cpu.csr_r1.storage.eq(r1)
            # yield cpu.csr_r2.storage.eq(r2)
            # yield cpu.csr_r3.storage.eq(r3)
            # yield cpu.csr_r4.storage.eq(r4)
            # yield cpu.csr_r5.storage.eq(r5)
            # yield

            self.tb.dut.r1.value = r1
            self.tb.dut.r2.value = r2
            self.tb.dut.r3.value = r3
            self.tb.dut.r4.value = r4
            self.tb.dut.r5.value = r5
            await RisingEdge(self.tb.dut.clk)

            print("Input:")
            print("R1: ({:20}, 0x{:016x}), R2: ({:20}, 0x{:016x})".format(r1, r1, r2, r2))
            print("R3: ({:20}, 0x{:016x}), R4: ({:20}, 0x{:016x})".format(r3, r3, r4, r4))
            print("R5: ({:20}, 0x{:016x})".format(r5, r5))

            # Open op-code statistics file
            test_file = test_data.get("filename", None)
            stat_file = None
            if test_file is not None:
                stat_file = os.path.splitext(test_file)[0] + ".stats"
                sfd = open(stat_file, "a")

            # End reset.
            self.tb.dut.reset_n.value = 1  # RESET LOW
            # reset is also deactivated
            """
            Perform actual test, control CPU signals like clock etc.
            """

            clk_cnt = 0

            # Prepare result to check
            result = None
            if 'result' in test_data:
                result = int(test_data['result'], 0)
                # overwriting this test case z
                # result = 0

            expected_error = 0
            expected_error_msg = None
            if 'error' in test_data:
                expected_error = 1
                expected_error_msg = test_data['error']

            expected = dict(re.findall(r'(\S+)\s*=\s*(".*?"|\S+)', test_data.get('expected', '')))
            #print(expected)
            expected_halt = 1 if int(expected.get('halt', '1'), 0) > 0 else 0
            # this can override error section above
            expected_error = 1 if int(expected.get('error', str(expected_error)), 0) > 0 else 0
            # overwriting above z
            # expected_error = 1

            max_clock_cycles = int(expected.get('clocks', str(default_max_clock_cycles)), 0)
            disable_test = int(expected.get('disable_sim_test', str("0")))

            if disable_test == 1:
                self.skipTest("Testcase not available for Simulator test")

            # Start with 5 clocks in reset.
            
            # yield cpu.reset_n.eq(0)
            # self.tb.dut.reset_n.value = 0  # RESET HIGH
                # reset must remain LOW/Deactivated
            
            # for i in range(5):
            #     # yield
            #     await RisingEdge(self.tb.dut.clk)

            # no extra clk cycles needed

            # set r1 - r5 input arguments
            args = test_data.get('args', {})
            r1 = int(str(args.get('r1', 0)), 0)
            r2 = int(str(args.get('r2', 0)), 0)
            r3 = int(str(args.get('r3', 0)), 0)
            r4 = int(str(args.get('r4', 0)), 0)
            r5 = int(str(args.get('r5', 0)), 0)
            # yield cpu.csr_r1.storage.eq(r1)
            # yield cpu.csr_r2.storage.eq(r2)
            # yield cpu.csr_r3.storage.eq(r3)
            # yield cpu.csr_r4.storage.eq(r4)
            # yield cpu.csr_r5.storage.eq(r5)
            # yield

            self.tb.dut.r1.value = r1
            self.tb.dut.r2.value = r2
            self.tb.dut.r3.value = r3
            self.tb.dut.r4.value = r4
            self.tb.dut.r5.value = r5
            # await RisingEdge(self.tb.dut.clk)

            print("Input:")
            print("R1: ({:20}, 0x{:016x}), R2: ({:20}, 0x{:016x})".format(r1, r1, r2, r2))
            print("R3: ({:20}, 0x{:016x}), R4: ({:20}, 0x{:016x})".format(r3, r3, r4, r4))
            print("R5: ({:20}, 0x{:016x})".format(r5, r5))

            # Open op-code statistics file
            test_file = test_data.get("filename", None)
            stat_file = None
            if test_file is not None:
                stat_file = os.path.splitext(test_file)[0] + ".stats"
                sfd = open(stat_file, "a")

            # End reset.
            # self.tb.dut.reset_n.value = 1  # RESET LOW
                # dont need to change value of reset since its already deactivated

            # dont need to do this if cond below cx its already been done in prev iteration
            # if (TestFPGA_Sim.flag_test_branch_VeBPF_DISL_Integration_v2_multi_VeBPFs_Rules):
            #     print("\n\nSetting reset VeBPF_prog_reset_in to LOW in method async def V_eBPF_cpu_test() for branch testing VeBPF_DISL_Integration_v2_multi_VeBPFs_Rules\n\n")
                # Setting reset for pgm also LOW for V-eBPF
                # self.tb.dut.VeBPF_prog_reset_in.value = 0


            # await RisingEdge(self.tb.dut.clk)
            # yield cpu.reset_n.eq(1)
            # yield


            # Clock CPU until halt, error or max clock cycles reached.
            # halt = (yield cpu.halt)
            # error = (yield cpu.error)
            # r0 = (yield cpu.r0)

            # now wait 1 clk cycle so that the values of halt error r0 ip_next are updated
                # halt wasn't modified cx I think 1 clk edge was needed to update run_next_selected_rule_en
                # to 0
            await RisingEdge(self.tb.dut.clk)
            
            # inserting a 2nd clk cycle cx the reg values werent updating below
            await RisingEdge(self.tb.dut.clk)

            # set flag run_next_selected_rule_en to 0 cx we only want to run a single next rule 
            self.tb.dut.run_next_selected_rule_en.value = 0

            print(f"{BOLD}{BRIGHT_YELLOW}Running VeBPF test{RESET}")
            print("\n!!!Running next rule now!!!!\n")
            print(f'self.tb.dut.ip_next_rule.value = {int(self.tb.dut.ip_next_rule.value)}')
            print(f'TestFPGA_Sim.instruction_pointer_next_VeBPF_rule = {TestFPGA_Sim.instruction_pointer_next_VeBPF_rule}')
            print(f'self.tb.dut.run_next_selected_rule_en.value = {self.tb.dut.run_next_selected_rule_en.value}')
            print(f'self.tb.dut.halt.value = {self.tb.dut.halt.value}')
            print(f'self.tb.dut.error.value = {self.tb.dut.error.value}')
            print(f'self.tb.dut.r0.value = {self.tb.dut.r0.value}')
            print(f'self.tb.dut.reset_n.value = {self.tb.dut.reset_n.value}')
            print(f'self.tb.dut.state_next.value = {int(self.tb.dut.state_next.value)}')

            await RisingEdge(self.tb.dut.clk)
            print("\nAfter 1 more clk cycle!!!!\n")
            print(f'self.tb.dut.ip_next_rule.value = {int(self.tb.dut.ip_next_rule.value)}')
            print(f'TestFPGA_Sim.instruction_pointer_next_VeBPF_rule = {TestFPGA_Sim.instruction_pointer_next_VeBPF_rule}')
            print(f'self.tb.dut.run_next_selected_rule_en.value = {self.tb.dut.run_next_selected_rule_en.value}')
            print(f'self.tb.dut.halt.value = {self.tb.dut.halt.value}')
            print(f'self.tb.dut.error.value = {self.tb.dut.error.value}')
            print(f'self.tb.dut.r0.value = {self.tb.dut.r0.value}')
            print(f'self.tb.dut.reset_n.value = {self.tb.dut.reset_n.value}')
            print(f'self.tb.dut.state_next.value = {int(self.tb.dut.state_next.value)}')

            halt = self.tb.dut.halt.value
            error = self.tb.dut.error.value
            r0 = self.tb.dut.r0.value



            while halt == 0 and clk_cnt <= max_clock_cycles:
                # break while loop when halt = 1 means our ebpf cpu finihsed processing
                # or the max clk cycles have been reached 
                
                halt = self.tb.dut.halt.value
                error = self.tb.dut.error.value
                r0 = self.tb.dut.r0.value
                r6 = self.tb.dut.r6.value 
                r7 = self.tb.dut.r7.value
                r8 = self.tb.dut.r8.value 
                r9 = self.tb.dut.r9.value
                r10 = self.tb.dut.r10.value 
                await RisingEdge(self.tb.dut.clk)
                
                # halt = (yield cpu.halt)
                # error = (yield cpu.error)
                # r0 = (yield cpu.r0)
                # r6 = (yield cpu.r6)
                # r7 = (yield cpu.r7)
                # r8 = (yield cpu.r8)
                # r9 = (yield cpu.r9)
                # r10 = (yield cpu.r10)
                # yield
                
                if not halt: # means halt is 0
                    clk_cnt += 1

            print("Output:")
            if result is None:
                # print("Clock cycles: ({}), halt: ({}), error: ({}), R0: ({:20}, 0x{:016x})".format(
                print("Clock cycles: ({}), halt: ({}), error: ({}), R0: (b'{}, d'{}, {})".format(
                    clk_cnt,
                    "LOW" if halt == 0 else "HIGH",
                    # "LOW" if error == 0 else "HIGH", r0, r0))
                    "LOW" if error == 0 else "HIGH", r0, int(r0), hex(r0)))

                # Error
                # print("Clock cycles: ({}), halt: ({}), error: ({}), R0: (b'{}, d'{}, 0x{}), expected R0: (d'{}, 0x{})".format(
                #     clk_cnt,
                #     "LOW" if halt == 0 else "HIGH",
                #     # "LOW" if error == 0 else "HIGH", r0, r0))
                #     "LOW" if error == 0 else "HIGH", r0, int(r0), hex(r0), result, hex(result)))

            else:
                print("Clock cycles: ({}), halt: ({}), error: ({}), R0: (b'{}, d'{}, {}), expected R0: (d'{}, {})".format(
                    clk_cnt,
                    "LOW" if halt == 0 else "HIGH",
                    # "LOW" if error == 0 else "HIGH", r0, r0))
                    "LOW" if error == 0 else "HIGH", r0, int(r0), hex(r0), result, hex(result)))



            # print("R6: ({:20}, 0x{:016x}), R7: ({:20}, 0x{:016x})".format(r6, r6, r7, r7))
            print("R6: ({}, {}), R7: ({}, {})".format(r6, hex(r6), r7, hex(r7)))

            # print("R8: ({:20}, 0x{:016x}), R9: ({:20}, 0x{:016x})".format(r8, r8, r9, r9))
            print("R8: ({}, {}), R9: ({}, {})".format(r8, hex(r8), r9, hex(r9)))
            
            # print("R10:({:20}, 0x{:016x})".format(r10, r10))
            print("R10:({}, {})".format(r10, hex(r10)))

            # Write clock cycles for this test to statistics file
            if stat_file is not None:
                do_graph = int(str(args.get('graph', 1)), 0)
                do_graph = 1 if do_graph > 0 else 0
                date = datetime.now().strftime("%Y%m%d-%H%M%S")
                sfd.write("\"SIM\",\"{}\",{},{},{},{}\n".format(date, clk_cnt, halt, error, do_graph))
                sfd.close()

            # Check result
            #if not expected_error:
            #    self.assertEqual(error, 0,
            #        "Action completes with error signal HIGH")
            #else:
            #    self.assertEqual(error, 1,
            #        "Action expected to complete with error signal HIGH but was LOW")
            #    if error_expected_msg is not None:
            #        print("Expected error: {}".format(error_expected_msg))
            #    return

            self.assertEqual(error, expected_error,
                ("Action does not complete with expected error signal level; " +
                    "was {} should be {}").format(error, expected_error))

            self.assertLessEqual(clk_cnt, max_clock_cycles,
                "Action did not complete within max clock cycles ({})".format(
                    max_clock_cycles))

            self.assertEqual(halt, expected_halt,
                ("Action does not complete with expected halt signal level; " +
                    "was {} should be {}").format(halt, expected_halt))

            # if result is not None:
            #     self.assertEqual(r0, result,
            #         ("Received result ({}, 0x{:08x}) not equal expected " +
            #         "({}, 0x{:08x})").format(
            #             r0, r0, result, result))

            if result is not None:
                self.assertEqual(r0, result,
                    ("Received result (b'{}, d'{}, {}) not equal expected " +
                    "(d'{}, {})").format(
                        r0, int(r0), hex(r0), result, hex(result)))

            big("Test Completed")


def generate_testcase(filename):
    async def test(self):
        await self.check_datafile(filename)
    return test



class TB:
    def __init__(self, dut, speed=100e6):
        self.dut = dut

        self.log = SimLog("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())  # clk delay here multiple of sys clk.. hence 10 ns for 100e6 

        # self.mii_phy = MiiPhy(dut.phy_txd, None, dut.phy_tx_en, dut.phy_tx_clk,
        #     dut.phy_rxd, dut.phy_rx_er, dut.phy_rx_dv, dut.phy_rx_clk, speed=speed)

        # dut.phy_crs.setimmediatevalue(0)
        # dut.phy_col.setimmediatevalue(0)

        # dut.btn.setimmediatevalue(0)
        # dut.sw.setimmediatevalue(0)  // in top.v
        # dut.uart_rxd.setimmediatevalue(0)  // not in top.v

    async def init(self):

        self.dut.reset_n.setimmediatevalue(0)
        self.dut.csr_ctl.setimmediatevalue(0)
        # self.dut.sw.setimmediatevalue(0)

        for k in range(10):
            await RisingEdge(self.dut.clk)

        self.dut.reset_n.setimmediatevalue(1)
        
        self.dut.csr_ctl.setimmediatevalue(1)
        
        self.dut.r1.setimmediatevalue(0)
        self.dut.r2.setimmediatevalue(0)
        self.dut.r3.setimmediatevalue(0)
        self.dut.r4.setimmediatevalue(0)
        self.dut.r5.setimmediatevalue(0)


@cocotb.test()
async def run_test(dut):

    # Makefile exports
    flag_reprog_test = int(os.getenv("REPROG", "0"))
    TestFPGA_Sim.flag_dump_sim_waveform = int(os.getenv("WAVE", "0"))
    TEST_CASE_FOLDER = os.getenv("TEST_CASE")
    print("TEST_CASE from Makefile:", TEST_CASE_FOLDER, type(TEST_CASE_FOLDER))
    print(f"[INFO] flag_reprog_test = {flag_reprog_test}")
    print(f"[INFO] TestFPGA_Sim.flag_dump_sim_waveform = {TestFPGA_Sim.flag_dump_sim_waveform}")

    if (flag_reprog_test):
        TestFPGA_Sim.flag_reprog_test = 1
        print("\n\nTesting reprogram functionality during this test run\n\n")

    tb = TB(dut)

    tb.log.info("testing Verilog eBPF")

    await tb.init()  # async def init(self): function in the coroutine 

    await Timer(3, units="us")

    # await RisingEdge(self.dut.clk)  # error .. self not defined since this is a method not in a class
    await RisingEdge(dut.clk)  

    # setting reset high again cx loading another pgm in verilog eBPF
    dut.reset_n.setimmediatevalue(0)
    dut.csr_ctl.setimmediatevalue(0) 

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # rename the edited unittest lib folder back to unittest and rename the edited unittest folder to unittest_original
    base_path = os.path.join(os.path.dirname(os.path.realpath(__file__)) , "eBPF_tests", TEST_CASE_FOLDER)

    test_files = testdatatools.testdata.list_files(base_path)
    if not test_files:
        raise RuntimeError(f"❌ No test files found in: {base_path}")

    # Attach dynamic test methods
    for filename in testdatatools.testdata.list_files(base_path):
        print(f"Listing file names here")
        print(f"filename = {filename}")
        filebase = filename[len(base_path):] if filename.startswith(base_path) else filename
        testname = 'test_' + '_'.join(os.path.splitext(filebase)[0].split(os.sep)).strip('_')
        setattr(TestFPGA_Sim, testname, generate_testcase(filename))

    test_instance = TestFPGA_Sim()
    test_instance.tb = tb  # attach cocotb testbench object

    print(f"Any file names above? While base_path = {base_path}")
        # Any file names above? While base_path = /home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/TEST1_ORIGINAL/data5_DISL_eBPF_test1
            # so this test should be failing but the problem is that is any test being run? Then that test should fail but if any test is not running then???

    # Run all async test methods
    await test_instance.run()



# cocotb-test
project_name = 'DISL_Verilog_eBPF' 

cwd = os.getcwd()

tests_dir = os.path.abspath(os.path.dirname(__file__))

proj_top_dir = os.path.join(cwd, '..', '..', project_name)


# def test_fpga_core(request):
# def test_top(request):
def test_cpu(request):
    # dut = "fpga_core"
    # dut = "top"
    dut = "cpu"
    module = os.path.splitext(os.path.basename(__file__))[0]  # test_top
    toplevel = dut

    verilog_sources = [
        os.path.join(proj_top_dir, f"{dut}.v"),
        # os.path.join(proj_top_dir, "data_memory.v"),
        # os.path.join(proj_top_dir, "memory.v"),
        os.path.join(proj_top_dir, "iverilog_dump.v"),  # testing verilog dump directly in python test file
        os.path.join(proj_top_dir, "iverilog_dump_sv.sv"),  # testing verilog dump directly in python test file
        os.path.join(proj_top_dir, "divider.v"),
        os.path.join(proj_top_dir, "call_handler.v"),
        os.path.join(proj_top_dir, "shifter.v"),
        os.path.join(proj_top_dir, "ram_module_v1.v"),
        os.path.join(proj_top_dir, "ram_module_v2.v"),
        os.path.join(proj_top_dir, "ram64_memory_v1.v")
    ]


    # set parameter overrides here
    parameters = { }

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    
    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )
