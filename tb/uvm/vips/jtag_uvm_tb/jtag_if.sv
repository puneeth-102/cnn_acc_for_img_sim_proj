interface jtag_if;
logic jtag_tck;
wire  clk = jtag_tck;
logic jtag_trst_n;
logic jtag_tms;
logic jtag_tdi;
logic jtag_tdo;
logic jtag_tdoEn;
endinterface
