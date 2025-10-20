# Makefile for DFE Verilog Project
# Supports both Icarus Verilog and ModelSim/QuestaSim

# Project directories
RTL_DIR = rtl
SIM_DIR = sim
PYTHON_DIR = python/python

# Source files
UTILS_SRC = $(RTL_DIR)/utils/signed_mult.v
POLYPHASE_SRC = $(RTL_DIR)/polyphase/fir_mac.v \
	            $(RTL_DIR)/polyphase/coefficient_rom.v \
	            $(RTL_DIR)/polyphase/polyphase_branch.v \
	            $(RTL_DIR)/polyphase/polyphase_resampler.v
NOTCH_SRC = $(RTL_DIR)/notch/biquad_df2t.v
CIC_SRC = $(RTL_DIR)/cic/cic_integrator.v \
	      $(RTL_DIR)/cic/cic_comb.v \
	      $(RTL_DIR)/cic/cic_decimator.v
TOP_SRC = $(RTL_DIR)/dfe_top.v
TB_SRC = $(SIM_DIR)/dfe_tb.v

ALL_SRC = $(UTILS_SRC) $(POLYPHASE_SRC) $(NOTCH_SRC) $(CIC_SRC) $(TOP_SRC) $(TB_SRC)

# Coefficient files
COEFF_FILES = $(PYTHON_DIR)/coeffs_fixed_q15.txt \
	          $(PYTHON_DIR)/notch_b_q14.txt \
	          $(PYTHON_DIR)/notch_a_q14.txt \
	          $(PYTHON_DIR)/comp_R2.txt \
	          $(PYTHON_DIR)/comp_R4.txt \
	          $(PYTHON_DIR)/comp_R8.txt \
	          $(PYTHON_DIR)/comp_R16.txt

# Simulation executables
IVERILOG_OUT = dfe_sim
VCD_FILE = dfe_tb.vcd
OUT_FILE = dfe_output.txt

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave
VLOG = vlog
VSIM = vsim

.PHONY: all clean help iverilog modelsim run view copy_coeff

# Default target
all: help

help:
	@echo "DFE Verilog Project - Makefile Help"
	@echo "===================================="
	@echo "Targets:"
	@echo "  iverilog     - Compile with Icarus Verilog"
	@echo "  modelsim     - Compile with ModelSim/QuestaSim"
	@echo "  run          - Run Icarus simulation"
	@echo "  view         - View waveforms with GTKWave"
	@echo "  copy_coeff   - Copy coefficient files to sim directory"
	@echo "  clean        - Remove generated files"
	@echo "  help         - Show this help message"

# Copy coefficient files to simulation directory
copy_coeff:
	@echo "Copying coefficient files..."
	@copy $(PYTHON_DIR)\coeffs_fixed_q15.txt $(SIM_DIR)\ 2>nul || echo "coeffs_fixed_q15.txt not found"
	@copy $(PYTHON_DIR)\notch_b_q14.txt $(SIM_DIR)\ 2>nul || echo "notch_b_q14.txt not found"
	@copy $(PYTHON_DIR)\notch_a_q14.txt $(SIM_DIR)\ 2>nul || echo "notch_a_q14.txt not found"
	@copy $(PYTHON_DIR)\comp_R2.txt $(SIM_DIR)\ 2>nul || echo "comp_R2.txt not found"
	@copy $(PYTHON_DIR)\comp_R4.txt $(SIM_DIR)\ 2>nul || echo "comp_R4.txt not found"
	@copy $(PYTHON_DIR)\comp_R8.txt $(SIM_DIR)\ 2>nul || echo "comp_R8.txt not found"
	@copy $(PYTHON_DIR)\comp_R16.txt $(SIM_DIR)\ 2>nul || echo "comp_R16.txt not found"

# Icarus Verilog compilation
iverilog: copy_coeff
	@echo "Compiling with Icarus Verilog..."
	$(IVERILOG) -o $(IVERILOG_OUT) -s dfe_tb $(ALL_SRC)
	@echo "Compilation successful: $(IVERILOG_OUT)"

# Run Icarus simulation
run: iverilog
	@echo "Running simulation..."
	cd $(SIM_DIR) && ..\\$(VVP) ..\\$(IVERILOG_OUT)
	@echo "Simulation complete. Output in $(SIM_DIR)/$(OUT_FILE)"

# View waveforms
view:
	@echo "Opening waveforms..."
	$(GTKWAVE) $(VCD_FILE) &

# ModelSim compilation
modelsim: copy_coeff
	@echo "Compiling with ModelSim..."
	$(VLOG) $(UTILS_SRC)
	$(VLOG) $(POLYPHASE_SRC)
	$(VLOG) $(NOTCH_SRC)
	$(VLOG) $(CIC_SRC)
	$(VLOG) $(TOP_SRC)
	$(VLOG) $(TB_SRC)
	@echo "Compilation successful"

# ModelSim simulation
modelsim_run: modelsim
	@echo "Running ModelSim simulation..."
	$(VSIM) -c dfe_tb -do "run -all; quit"

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@del /Q $(IVERILOG_OUT) 2>nul || echo ""
	@del /Q $(VCD_FILE) 2>nul || echo ""
	@del /Q $(SIM_DIR)\$(OUT_FILE) 2>nul || echo ""
	@del /Q $(SIM_DIR)\*.txt 2>nul || echo ""
	@del /Q work\*.* 2>nul || echo ""
	@rmdir /Q work 2>nul || echo ""
	@del /Q transcript 2>nul || echo ""
	@del /Q vsim.wlf 2>nul || echo ""
	@echo "Clean complete"

# List all source files
list:
	@echo "Source files:"
	@echo "============="
	@for %%f in ($(ALL_SRC)) do @echo   %%f