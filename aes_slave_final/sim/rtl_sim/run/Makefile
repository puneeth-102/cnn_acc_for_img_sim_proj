##########################################################################
#  AES Core – VCS + Verdi Simulation Makefile
#  Run from:  sim/rtl_sim/run/
#  Usage:
#    make compile    – elaborate with VCS
#    make sim        – compile + run simulation (generates FSDB)
#    make verdi      – open Verdi with the generated FSDB
#    make all        – compile + sim + verdi
#    make clean      – remove generated files
##########################################################################

SHELL = /bin/sh

##########################################################################
# Tool paths  (sourced from cshrc / set here as fallback)
##########################################################################
VCS_HOME   ?= /home/student/snps_tools_target/vcs/U-2023.03
VERDI_HOME ?= /home/student/snps_tools_target/verdi/U-2023.03-SP1

VCS    = $(VCS_HOME)/bin/vcs
VERDI  = $(VERDI_HOME)/bin/verdi

##########################################################################
# License
##########################################################################
export SNPSLMD_LICENSE_FILE = 27021@14.139.1.126

##########################################################################
# Source file lists
##########################################################################
DUT_SRC_DIR = ../../../rtl/verilog
TB_SRC_DIR  = ../../../bench/verilog

DUT_SRCS = \
    $(DUT_SRC_DIR)/aes_sbox.v            \
    $(DUT_SRC_DIR)/aes_rcon.v            \
    $(DUT_SRC_DIR)/aes_key_expand_128.v  \
    $(DUT_SRC_DIR)/aes_cipher_top.v      \
    $(DUT_SRC_DIR)/aes_inv_sbox.v        \
    $(DUT_SRC_DIR)/aes_inv_cipher_top.v

TB_SRCS = $(TB_SRC_DIR)/test_bench_top.v

ALL_SRCS = $(DUT_SRCS) $(TB_SRCS)

##########################################################################
# VCS / Verdi options
##########################################################################
TOP_MODULE  = test
FSDB_FILE   = waves/aes_dump.fsdb

# Include directories
INCDIRS = +incdir+$(DUT_SRC_DIR) +incdir+$(TB_SRC_DIR)

# Verdi PLI library for FSDB dumping
NOVAS_PLI   = $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab
NOVAS_PLI_C = $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a

VCS_FLAGS = \
    -full64               \
    -sverilog             \
    -timescale=1ns/1ps    \
    +define+RUDIS_TB      \
    +define+WAVES         \
    $(INCDIRS)            \
    -P $(NOVAS_PLI)       \
    $(NOVAS_PLI_C)        \
    -o simv               \
    -l compile.log

SIM_FLAGS = \
    +fsdb+autoflush       \
    -l sim.log

##########################################################################
# Targets
##########################################################################
.PHONY: all compile sim verdi clean

all: sim verdi

compile:
	@echo "==> Compiling with VCS ..."
	@mkdir -p waves
	$(VCS) $(VCS_FLAGS) $(ALL_SRCS)
	@echo "==> Compile done."

sim: compile
	@echo "==> Running simulation ..."
	./simv $(SIM_FLAGS)
	@echo "==> Simulation done. FSDB: $(FSDB_FILE)"

verdi:
	@echo "==> Opening Verdi ..."
	$(VERDI) -sv                          \
	    $(INCDIRS)                        \
	    +define+RUDIS_TB                  \
	    +define+WAVES                     \
	    -f /dev/null                      \
	    -ssf $(FSDB_FILE)                 \
	    -top $(TOP_MODULE)               \
	    $(ALL_SRCS) &

clean:
	@echo "==> Cleaning ..."
	rm -rf simv simv.daidir csrc \
	       compile.log sim.log   \
	       ucli.key vc_hdrs.h    \
	       waves/*.fsdb          \
	       verdiLog novas.conf   \
	       64 AN.DB
	@echo "==> Clean done."

##########################################################################
