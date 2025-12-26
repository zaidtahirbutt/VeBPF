TOPLEVEL_LANG = verilog
SIM ?= icarus
# WAVES ?= 1
COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 10ps  # same as defined in verilog top file

DUT      = cpu
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
PROJECT_NAME = VeBPF

# Custom simulation flags passed to Python via environment
export REPROG ?= 0
export WAVE ?= 1
export TEST_CASE ?= eBPF_all_instructions
export VEBPF_SIM ?= 1


# 2025 latest branch
VERILOG_SOURCES += ../$(DUT).v
VERILOG_SOURCES += ../ram_module_v3.v
VERILOG_SOURCES += ../ram64_memory_v3.v
VERILOG_SOURCES += ../divider.v
VERILOG_SOURCES += ../call_handler.v
VERILOG_SOURCES += ../shifter.v
VERILOG_SOURCES += ../iverilog_dump_sv.sv
VERILOG_SOURCES += ../ram64_memory_v1.v

ifeq ($(SIM), icarus)
	PLUSARGS += -fst
	# Add parameter override
    ifdef VEBPF_SIM
        COMPILE_ARGS += -P cpu.VEBPF_SIM=$(VEBPF_SIM)
    endif
	
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH
	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif
	ifdef VEBPF_SIM
		COMPILE_ARGS += -G VEBPF_SIM=$(VEBPF_SIM)
	endif
endif

# Define custom test targets
.PHONY: clean_fst_stats ebpf_inst_1_add ebpf_inst_2_alu64-arith ebpf_inst_3_alu64-bit ebpf_inst_4_alu-arith \
ebpf_inst_5_alu-bit ebpf_inst_6_arsh ebpf_inst_7_arsh32-high-shift ebpf_inst_8_arsh64-combined ebpf_inst_9_arsh64-imm \
ebpf_inst_10_arsh64-imm-neg ebpf_inst_11_arsh64-imm-pos ebpf_inst_12_arsh64-reg ebpf_inst_13_arsh-reg ebpf_inst_14_be16 ebpf_inst_15_be16-high \
ebpf_inst_16_be32 ebpf_inst_17_be32-high ebpf_inst_18_be64 ebpf_inst_19_call_z1 ebpf_inst_20_call_z2 ebpf_inst_21_div32-high-divisor ebpf_inst_22_div32-imm \
ebpf_inst_23_div32-reg ebpf_inst_24_div64-imm ebpf_inst_25_div64-reg ebpf_inst_26_early-exit ebpf_inst_27_err-div64-by-zero-reg ebpf_inst_28_err-div-by-zero-imm \
ebpf_inst_29_err-div-by-zero-reg ebpf_inst_30_err-endian-size ebpf_inst_31_err-incomplete-lddw ebpf_inst_32_err-invalid-reg-dst ebpf_inst_33_err-invalid-reg-src \
ebpf_inst_34_err-jmp-lddw ebpf_inst_35_err-mod64-by-zero-reg ebpf_inst_36_err-mod-by-zero-reg ebpf_inst_37_err-unknown-opcode ebpf_inst_38_exit ebpf_inst_39_exit-not-last \
ebpf_inst_40_ja ebpf_inst_41_jeq-imm ebpf_inst_42_jeq-reg ebpf_inst_43_jge-imm ebpf_inst_44_jgt-imm ebpf_inst_45_jgt-reg ebpf_inst_46_jit-bounce ebpf_inst_47_jle-imm \
ebpf_inst_48_jle-reg ebpf_inst_49_jlt-imm ebpf_inst_50_jlt-reg ebpf_inst_51_jne-reg ebpf_inst_52_jset-imm ebpf_inst_53_jset-reg ebpf_inst_54_jsge-imm \
ebpf_inst_55_jsge-reg ebpf_inst_56_jsgt-imm ebpf_inst_57_jsgt-reg ebpf_inst_58_jsle-imm ebpf_inst_59_jsle-reg ebpf_inst_60_jslt-imm ebpf_inst_61_jslt-reg \
ebpf_inst_62_lddw ebpf_inst_63_lddw2 ebpf_inst_64_ldxb ebpf_inst_65_ldxb-all ebpf_inst_66_ldxdw ebpf_inst_67_ldxh ebpf_inst_68_ldxh-all ebpf_inst_69_ldxh-all2 \
ebpf_inst_70_ldxh-same-reg ebpf_inst_71_ldxw ebpf_inst_72_ldxw-all ebpf_inst_73_le16 ebpf_inst_74_le32 ebpf_inst_75_le64 ebpf_inst_76_lsh-reg ebpf_inst_77_mod \
ebpf_inst_78_mod32 ebpf_inst_79_mod64 ebpf_inst_80_mov ebpf_inst_81_mul32-imm ebpf_inst_82_mul32-reg ebpf_inst_83_mul32-reg-overflow ebpf_inst_84_mul64-imm \
ebpf_inst_85_mul64-reg ebpf_inst_86_neg ebpf_inst_87_neg64 ebpf_inst_88_rsh32 ebpf_inst_89_rsh-reg ebpf_inst_90_stb ebpf_inst_91_stdw ebpf_inst_92_sth \
ebpf_inst_93_stw ebpf_inst_94_stxb ebpf_inst_95_stxb-all ebpf_inst_96_stxb-all2 ebpf_inst_97_stxb-chain ebpf_inst_98_stxdw ebpf_inst_99_stxh ebpf_inst_100_stxw \
eBPF_all_instructions eBPF_all_instructions_except_call

eBPF_all_instructions:
	$(MAKE) TEST_CASE=eBPF_all_instructions sim

clean_fst_stats:
	@find ./eBPF_tests -mindepth 2 -type f \( -name "*.fst" -o -name "*.stats" \) -exec rm -f {} +
	@echo "All .fst and .stats files in ../eBPF_tests subfolders have been deleted."

eBPF_all_instructions_except_call:
	$(MAKE) TEST_CASE=eBPF_all_instructions_except_call sim

ebpf_inst_1_add:
	$(MAKE) TEST_CASE=ebpf_inst_1_add sim

ebpf_inst_2_alu64-arith:
	$(MAKE) TEST_CASE=ebpf_inst_2_alu64-arith sim

ebpf_inst_3_alu64-bit:
	$(MAKE) TEST_CASE=ebpf_inst_3_alu64-bit sim

ebpf_inst_4_alu-arith:
	$(MAKE) TEST_CASE=ebpf_inst_4_alu-arith sim

ebpf_inst_5_alu-bit:
	$(MAKE) TEST_CASE=ebpf_inst_5_alu-bit sim

ebpf_inst_6_arsh:
	$(MAKE) TEST_CASE=ebpf_inst_6_arsh sim

ebpf_inst_7_arsh32-high-shift:
	$(MAKE) TEST_CASE=ebpf_inst_7_arsh32-high-shift sim

ebpf_inst_8_arsh64-combined:
	$(MAKE) TEST_CASE=ebpf_inst_8_arsh64-combined sim

ebpf_inst_9_arsh64-imm:
	$(MAKE) TEST_CASE=ebpf_inst_9_arsh64-imm sim

ebpf_inst_10_arsh64-imm-neg:
	$(MAKE) TEST_CASE=ebpf_inst_10_arsh64-imm-neg sim

ebpf_inst_11_arsh64-imm-pos:
	$(MAKE) TEST_CASE=ebpf_inst_11_arsh64-imm-pos sim

ebpf_inst_12_arsh64-reg:
	$(MAKE) TEST_CASE=ebpf_inst_12_arsh64-reg sim

ebpf_inst_13_arsh-reg:
	$(MAKE) TEST_CASE=ebpf_inst_13_arsh-reg sim

ebpf_inst_14_be16:
	$(MAKE) TEST_CASE=ebpf_inst_14_be16 sim

ebpf_inst_15_be16-high:
	$(MAKE) TEST_CASE=ebpf_inst_15_be16-high sim

ebpf_inst_16_be32:
	$(MAKE) TEST_CASE=ebpf_inst_16_be32 sim

ebpf_inst_17_be32-high:
	$(MAKE) TEST_CASE=ebpf_inst_17_be32-high sim

ebpf_inst_18_be64:
	$(MAKE) TEST_CASE=ebpf_inst_18_be64 sim

ebpf_inst_19_call_z1:
	$(MAKE) TEST_CASE=ebpf_inst_19_call_z1 sim

ebpf_inst_20_call_z2:
	$(MAKE) TEST_CASE=ebpf_inst_20_call_z2 sim

ebpf_inst_21_div32-high-divisor:
	$(MAKE) TEST_CASE=ebpf_inst_21_div32-high-divisor sim

ebpf_inst_22_div32-imm:
	$(MAKE) TEST_CASE=ebpf_inst_22_div32-imm sim

ebpf_inst_23_div32-reg:
	$(MAKE) TEST_CASE=ebpf_inst_23_div32-reg sim

ebpf_inst_24_div64-imm:
	$(MAKE) TEST_CASE=ebpf_inst_24_div64-imm sim

ebpf_inst_25_div64-reg:
	$(MAKE) TEST_CASE=ebpf_inst_25_div64-reg sim

ebpf_inst_26_early-exit:
	$(MAKE) TEST_CASE=ebpf_inst_26_early-exit sim

ebpf_inst_27_err-div64-by-zero-reg:
	$(MAKE) TEST_CASE=ebpf_inst_27_err-div64-by-zero-reg sim

ebpf_inst_28_err-div-by-zero-imm:
	$(MAKE) TEST_CASE=ebpf_inst_28_err-div-by-zero-imm sim

ebpf_inst_29_err-div-by-zero-reg:
	$(MAKE) TEST_CASE=ebpf_inst_29_err-div-by-zero-reg sim

ebpf_inst_30_err-endian-size:
	$(MAKE) TEST_CASE=ebpf_inst_30_err-endian-size sim

ebpf_inst_31_err-incomplete-lddw:
	$(MAKE) TEST_CASE=ebpf_inst_31_err-incomplete-lddw sim

ebpf_inst_32_err-invalid-reg-dst:
	$(MAKE) TEST_CASE=ebpf_inst_32_err-invalid-reg-dst sim

ebpf_inst_33_err-invalid-reg-src:
	$(MAKE) TEST_CASE=ebpf_inst_33_err-invalid-reg-src sim

ebpf_inst_34_err-jmp-lddw:
	$(MAKE) TEST_CASE=ebpf_inst_34_err-jmp-lddw sim

ebpf_inst_35_err-mod64-by-zero-reg:
	$(MAKE) TEST_CASE=ebpf_inst_35_err-mod64-by-zero-reg sim

ebpf_inst_36_err-mod-by-zero-reg:
	$(MAKE) TEST_CASE=ebpf_inst_36_err-mod-by-zero-reg sim

ebpf_inst_37_err-unknown-opcode:
	$(MAKE) TEST_CASE=ebpf_inst_37_err-unknown-opcode sim

ebpf_inst_38_exit:
	$(MAKE) TEST_CASE=ebpf_inst_38_exit sim

ebpf_inst_39_exit-not-last:
	$(MAKE) TEST_CASE=ebpf_inst_39_exit-not-last sim

ebpf_inst_40_ja:
	$(MAKE) TEST_CASE=ebpf_inst_40_ja sim

ebpf_inst_41_jeq-imm:
	$(MAKE) TEST_CASE=ebpf_inst_41_jeq-imm sim

ebpf_inst_42_jeq-reg:
	$(MAKE) TEST_CASE=ebpf_inst_42_jeq-reg sim

ebpf_inst_43_jge-imm:
	$(MAKE) TEST_CASE=ebpf_inst_43_jge-imm sim

ebpf_inst_44_jgt-imm:
	$(MAKE) TEST_CASE=ebpf_inst_44_jgt-imm sim

ebpf_inst_45_jgt-reg:
	$(MAKE) TEST_CASE=ebpf_inst_45_jgt-reg sim

ebpf_inst_46_jit-bounce:
	$(MAKE) TEST_CASE=ebpf_inst_46_jit-bounce sim

ebpf_inst_47_jle-imm:
	$(MAKE) TEST_CASE=ebpf_inst_47_jle-imm sim

ebpf_inst_48_jle-reg:
	$(MAKE) TEST_CASE=ebpf_inst_48_jle-reg sim

ebpf_inst_49_jlt-imm:
	$(MAKE) TEST_CASE=ebpf_inst_49_jlt-imm sim

ebpf_inst_50_jlt-reg:
	$(MAKE) TEST_CASE=ebpf_inst_50_jlt-reg sim

ebpf_inst_51_jne-reg:
	$(MAKE) TEST_CASE=ebpf_inst_51_jne-reg sim

ebpf_inst_52_jset-imm:
	$(MAKE) TEST_CASE=ebpf_inst_52_jset-imm sim

ebpf_inst_53_jset-reg:
	$(MAKE) TEST_CASE=ebpf_inst_53_jset-reg sim

ebpf_inst_54_jsge-imm:
	$(MAKE) TEST_CASE=ebpf_inst_54_jsge-imm sim

ebpf_inst_55_jsge-reg:
	$(MAKE) TEST_CASE=ebpf_inst_55_jsge-reg sim

ebpf_inst_56_jsgt-imm:
	$(MAKE) TEST_CASE=ebpf_inst_56_jsgt-imm sim

ebpf_inst_57_jsgt-reg:
	$(MAKE) TEST_CASE=ebpf_inst_57_jsgt-reg sim

ebpf_inst_58_jsle-imm:
	$(MAKE) TEST_CASE=ebpf_inst_58_jsle-imm sim

ebpf_inst_59_jsle-reg:
	$(MAKE) TEST_CASE=ebpf_inst_59_jsle-reg sim

ebpf_inst_60_jslt-imm:
	$(MAKE) TEST_CASE=ebpf_inst_60_jslt-imm sim

ebpf_inst_61_jslt-reg:
	$(MAKE) TEST_CASE=ebpf_inst_61_jslt-reg sim

ebpf_inst_62_lddw:
	$(MAKE) TEST_CASE=ebpf_inst_62_lddw sim

ebpf_inst_63_lddw2:
	$(MAKE) TEST_CASE=ebpf_inst_63_lddw2 sim

ebpf_inst_64_ldxb:
	$(MAKE) TEST_CASE=ebpf_inst_64_ldxb sim

ebpf_inst_65_ldxb-all:
	$(MAKE) TEST_CASE=ebpf_inst_65_ldxb-all sim

ebpf_inst_66_ldxdw:
	$(MAKE) TEST_CASE=ebpf_inst_66_ldxdw sim

ebpf_inst_67_ldxh:
	$(MAKE) TEST_CASE=ebpf_inst_67_ldxh sim

ebpf_inst_68_ldxh-all:
	$(MAKE) TEST_CASE=ebpf_inst_68_ldxh-all sim

ebpf_inst_69_ldxh-all2:
	$(MAKE) TEST_CASE=ebpf_inst_69_ldxh-all2 sim

ebpf_inst_70_ldxh-same-reg:
	$(MAKE) TEST_CASE=ebpf_inst_70_ldxh-same-reg sim

ebpf_inst_71_ldxw:
	$(MAKE) TEST_CASE=ebpf_inst_71_ldxw sim

ebpf_inst_72_ldxw-all:
	$(MAKE) TEST_CASE=ebpf_inst_72_ldxw-all sim

ebpf_inst_73_le16:
	$(MAKE) TEST_CASE=ebpf_inst_73_le16 sim

ebpf_inst_74_le32:
	$(MAKE) TEST_CASE=ebpf_inst_74_le32 sim

ebpf_inst_75_le64:
	$(MAKE) TEST_CASE=ebpf_inst_75_le64 sim

ebpf_inst_76_lsh-reg:
	$(MAKE) TEST_CASE=ebpf_inst_76_lsh-reg sim

ebpf_inst_77_mod:
	$(MAKE) TEST_CASE=ebpf_inst_77_mod sim

ebpf_inst_78_mod32:
	$(MAKE) TEST_CASE=ebpf_inst_78_mod32 sim

ebpf_inst_79_mod64:
	$(MAKE) TEST_CASE=ebpf_inst_79_mod64 sim

ebpf_inst_80_mov:
	$(MAKE) TEST_CASE=ebpf_inst_80_mov sim

ebpf_inst_81_mul32-imm:
	$(MAKE) TEST_CASE=ebpf_inst_81_mul32-imm sim

ebpf_inst_82_mul32-reg:
	$(MAKE) TEST_CASE=ebpf_inst_82_mul32-reg sim

ebpf_inst_83_mul32-reg-overflow:
	$(MAKE) TEST_CASE=ebpf_inst_83_mul32-reg-overflow sim

ebpf_inst_84_mul64-imm:
	$(MAKE) TEST_CASE=ebpf_inst_84_mul64-imm sim

ebpf_inst_85_mul64-reg:
	$(MAKE) TEST_CASE=ebpf_inst_85_mul64-reg sim

ebpf_inst_86_neg:
	$(MAKE) TEST_CASE=ebpf_inst_86_neg sim

ebpf_inst_87_neg64:
	$(MAKE) TEST_CASE=ebpf_inst_87_neg64 sim

ebpf_inst_88_rsh32:
	$(MAKE) TEST_CASE=ebpf_inst_88_rsh32 sim

ebpf_inst_89_rsh-reg:
	$(MAKE) TEST_CASE=ebpf_inst_89_rsh-reg sim

ebpf_inst_90_stb:
	$(MAKE) TEST_CASE=ebpf_inst_90_stb sim

ebpf_inst_91_stdw:
	$(MAKE) TEST_CASE=ebpf_inst_91_stdw sim

ebpf_inst_92_sth:
	$(MAKE) TEST_CASE=ebpf_inst_92_sth sim

ebpf_inst_93_stw:
	$(MAKE) TEST_CASE=ebpf_inst_93_stw sim

ebpf_inst_94_stxb:
	$(MAKE) TEST_CASE=ebpf_inst_94_stxb sim

ebpf_inst_95_stxb-all:
	$(MAKE) TEST_CASE=ebpf_inst_95_stxb-all sim

ebpf_inst_96_stxb-all2:
	$(MAKE) TEST_CASE=ebpf_inst_96_stxb-all2 sim

ebpf_inst_97_stxb-chain:
	$(MAKE) TEST_CASE=ebpf_inst_97_stxb-chain sim

ebpf_inst_98_stxdw:
	$(MAKE) TEST_CASE=ebpf_inst_98_stxdw sim

ebpf_inst_99_stxh:
	$(MAKE) TEST_CASE=ebpf_inst_99_stxh sim

ebpf_inst_100_stxw:
	$(MAKE) TEST_CASE=ebpf_inst_100_stxw sim



include $(shell cocotb-config --makefiles)/Makefile.sim