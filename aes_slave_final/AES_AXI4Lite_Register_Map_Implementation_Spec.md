# AES-128 AXI4-Lite Register-Mapped Wrapper --- Implementation Specification

## 1. Objective

Build an **AXI4-Lite slave wrapper around the existing AES-128 RTL
core**.

The wrapper must expose the AES core through a **32-bit memory-mapped
register interface** so an AXI master can:

1.  Write a 128-bit AES key using four 32-bit registers.
2.  Write a 128-bit input text block using four 32-bit registers.
3.  Control the AES core using control bits represented in a 32-bit CPSR
    register.
4.  Observe `done` and `kdone` through the same CPSR register.
5.  Read the 128-bit output text through four 32-bit registers.
6.  Support both the existing forward cipher and inverse cipher where
    appropriate.

This specification is based on the supplied AES Rijndael IP
documentation and the existing project structure. Do not redesign the
AES algorithm unless required for integration.

------------------------------------------------------------------------

# 2. Existing AES Core Interface

The supplied AES IP documentation defines two interfaces.

## AES Cipher / Encryption Core

``` text
clk       : input
rst       : input, active-low synchronous reset
ld        : input, load/start
done      : output, completion
key[127:0]     : input
text_in[127:0] : input
text_out[127:0]: output
```

## AES Inverse Cipher / Decryption Core

``` text
clk       : input
rst       : input, active-low synchronous reset
kld       : input, key load
kdone     : output, key expansion complete
ld        : input, text load/start
done      : output, text operation complete
key[127:0]     : input
text_in[127:0] : input
text_out[127:0]: output
```

The inverse core requires the key to be loaded/expanded before a
decryption operation. The expanded keys are stored internally and reused
for subsequent decryptions with the same key.

The supplied documentation states that AES-128 uses 10 rounds and that
the forward and inverse operations use a 12-cycle sequence as described
by the IP documentation.

------------------------------------------------------------------------

# 3. Main Design Concept

The architecture should be:

``` text
                    AXI4-Lite MASTER
                           |
                           | 32-bit AXI transactions
                           v
                 +----------------------+
                 |    AXI4-Lite SLAVE   |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 |   REGISTER MAP       |
                 |                      |
                 | CPSR                 |
                 | KEY0..KEY3           |
                 | TEXT_IN0..TEXT_IN3   |
                 | TEXT_OUT0..TEXT_OUT3 |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 | AES CONTROL LOGIC    |
                 +----------+-----------+
                            |
              +-------------+-------------+
              |                           |
              v                           v
       AES Cipher Core            AES Inverse Cipher
       (encryption)               (decryption)
```

The AXI wrapper is responsible for protocol handling, register storage,
address decoding, and conversion between 32-bit AXI registers and the
AES core's 128-bit interfaces.

The existing AES datapath/key expansion/S-box RTL should be reused.

------------------------------------------------------------------------

# 4. Register Map

Use a 32-bit AXI data bus.

  Address   Register      Access   Description
  --------- ------------- -------- -----------------------------
  `0x00`    `CPSR`        R/W      AES control/status signals
  `0x04`    `KEY0`        R/W      Key bits `[31:0]`
  `0x08`    `KEY1`        R/W      Key bits `[63:32]`
  `0x0C`    `KEY2`        R/W      Key bits `[95:64]`
  `0x10`    `KEY3`        R/W      Key bits `[127:96]`
  `0x14`    `TEXT_IN0`    R/W      Input text bits `[31:0]`
  `0x18`    `TEXT_IN1`    R/W      Input text bits `[63:32]`
  `0x1C`    `TEXT_IN2`    R/W      Input text bits `[95:64]`
  `0x20`    `TEXT_IN3`    R/W      Input text bits `[127:96]`
  `0x24`    `TEXT_OUT0`   R        Output text bits `[31:0]`
  `0x28`    `TEXT_OUT1`   R        Output text bits `[63:32]`
  `0x2C`    `TEXT_OUT2`   R        Output text bits `[95:64]`
  `0x30`    `TEXT_OUT3`   R        Output text bits `[127:96]`

Do not add unnecessary registers unless required by the AXI
implementation.

------------------------------------------------------------------------

# 5. CPSR Register

The CPSR is the main 32-bit control/status register.

Recommended bit allocation:

``` text
31                    6 5    4    3     2    1    0
+----------------------+-----+----+-----+----+----+----+
|      RESERVED       |MODE |RST |KDONE|KLD |DONE| LD |
+----------------------+-----+----+-----+----+----+----+
```

More explicitly:

  --------------------------------------------------------------------------------
                    Bit Name             Direction /       Meaning
                                         Behavior          
  --------------------- ---------------- ----------------- -----------------------
                    `0` `LD`             R/W               Drives AES `ld`
                                         command/control   

                    `1` `DONE`           Read/status       Reflects AES `done`

                    `2` `KLD`            R/W               Drives inverse AES
                                         command/control   `kld`

                    `3` `KDONE`          Read/status       Reflects AES `kdone`

                    `4` `RST`            R/W control       Drives/reset control as
                                                           defined by wrapper

                    `5` `MODE`           R/W control       Select
                                                           encryption/decryption

                 `31:6` RESERVED         ---               Reserved for future use
  --------------------------------------------------------------------------------

Important:

-   `LD` and `KLD` correspond to the actual AES input control signals.
-   `DONE` and `KDONE` correspond to the actual AES output status
    signals.
-   The register must not pretend that all four signals have the same
    direction.
-   `LD` and `KLD` should normally be implemented as one-clock control
    events when commanded, because the underlying AES interface uses
    them as load controls.
-   `DONE` and `KDONE` should reflect the AES core outputs and remain
    visible to the AXI master for status checking.
-   `MODE=0`: encryption / forward cipher.
-   `MODE=1`: decryption / inverse cipher.

If the exact reset polarity/interface is handled at the AXI wrapper
boundary, preserve the AES core's documented **active-low synchronous
reset** behavior.

------------------------------------------------------------------------

# 6. Why CPSR Contains These Signals

The faculty requirement is that the register itself represent the AES
interface signals.

Therefore the design should not hide `ld`, `kld`, `done`, and `kdone`
behind an unrelated command register.

The intended relationship is:

``` text
AXI write CPSR[0]
        |
        v
      AES ld

AXI write CPSR[2]
        |
        v
      AES kld

AES done
   |
   v
CPSR[1]

AES kdone
   |
   v
CPSR[3]
```

Thus the CPSR acts as the software-visible control/status representation
of the AES core interface.

------------------------------------------------------------------------

# 7. 128-bit Key Register Mapping

The AES core requires:

``` text
key[127:0]
```

The AXI interface is 32-bit, so split the key into four registers:

``` text
KEY0 = key[31:0]
KEY1 = key[63:32]
KEY2 = key[95:64]
KEY3 = key[127:96]
```

Internal connection:

``` verilog
assign aes_key = {KEY3, KEY2, KEY1, KEY0};
```

Do not reverse this ordering accidentally.

The exact byte ordering used by the original AES RTL/testbench must also
be preserved. Do not change AES byte ordering merely to make the
register map look different.

------------------------------------------------------------------------

# 8. 128-bit TEXT_IN Mapping

Use:

``` text
TEXT_IN0 = text_in[31:0]
TEXT_IN1 = text_in[63:32]
TEXT_IN2 = text_in[95:64]
TEXT_IN3 = text_in[127:96]
```

Internal connection:

``` verilog
assign aes_text_in = {
    TEXT_IN3,
    TEXT_IN2,
    TEXT_IN1,
    TEXT_IN0
};
```

`TEXT_IN` represents the 128-bit block supplied to the AES core.

For encryption this is plaintext.

For decryption this is ciphertext.

------------------------------------------------------------------------

# 9. 128-bit TEXT_OUT Mapping

The AES core generates:

``` text
text_out[127:0]
```

Expose it as:

``` text
TEXT_OUT0 = text_out[31:0]
TEXT_OUT1 = text_out[63:32]
TEXT_OUT2 = text_out[95:64]
TEXT_OUT3 = text_out[127:96]
```

Internal readback:

``` verilog
TEXT_OUT0 = aes_text_out[31:0];
TEXT_OUT1 = aes_text_out[63:32];
TEXT_OUT2 = aes_text_out[95:64];
TEXT_OUT3 = aes_text_out[127:96];
```

`TEXT_OUT` should be read-only from the AXI master's point of view.

------------------------------------------------------------------------

# 10. Encryption Operation

For encryption, use the existing forward AES cipher core.

Expected sequence:

``` text
1. AXI master writes KEY0..KEY3
2. AXI master writes TEXT_IN0..TEXT_IN3
3. Set MODE = 0
4. Generate LD = 1 for one clock
5. AES encryption executes
6. AES asserts DONE
7. CPSR.DONE becomes visible to AXI master
8. AXI master reads TEXT_OUT0..TEXT_OUT3
```

Conceptually:

``` text
AXI MASTER
    |
    | KEY
    v
KEY REGISTERS
    |
    | 128-bit key
    v
AES CIPHER
    ^
    |
TEXT_IN
    |
    | LD
    v
start operation

AES CIPHER
    |
    | DONE
    v
CPSR.DONE
    |
    v
AXI MASTER reads TEXT_OUT
```

The supplied IP documentation says the forward cipher begins when `ld`
is asserted and indicates completion using `done`.

------------------------------------------------------------------------

# 11. Decryption Operation

For decryption, use the existing inverse AES cipher core.

Expected sequence:

``` text
1. AXI master writes KEY0..KEY3
2. AXI master requests KLD
3. Wrapper generates kld for the inverse AES core
4. AES key expansion occurs
5. AES asserts kdone
6. CPSR.KDONE becomes visible
7. AXI master writes TEXT_IN0..TEXT_IN3
8. Set MODE = 1
9. Generate LD for one clock
10. AES decryption executes
11. AES asserts DONE
12. CPSR.DONE becomes visible
13. AXI master reads TEXT_OUT0..TEXT_OUT3
```

Important:

``` text
KLD/KDONE
```

are needed for the inverse core because its key expansion must occur
before the decryption sequence.

The same key can then be reused for subsequent inverse operations
according to the supplied IP documentation.

------------------------------------------------------------------------

# 12. AXI4-Lite Interface

The wrapper should implement a standard 32-bit AXI4-Lite slave.

Required channels:

## Write address

``` text
s_axi_awaddr
s_axi_awvalid
s_axi_awready
```

## Write data

``` text
s_axi_wdata[31:0]
s_axi_wstrb[3:0]
s_axi_wvalid
s_axi_wready
```

## Write response

``` text
s_axi_bresp[1:0]
s_axi_bvalid
s_axi_bready
```

## Read address

``` text
s_axi_araddr
s_axi_arvalid
s_axi_arready
```

## Read data

``` text
s_axi_rdata[31:0]
s_axi_rresp[1:0]
s_axi_rvalid
s_axi_rready
```

AXI protocol handling must be kept separate from AES datapath logic as
much as practical.

------------------------------------------------------------------------

# 13. AXI Write Behavior

When a valid AXI write transaction completes:

``` text
AWVALID & AWREADY
WVALID  & WREADY
```

decode the address and update the corresponding register.

Examples:

``` text
AWADDR = 0x04
WDATA  = key word
        |
        v
KEY0/KEY1/etc.
```

For CPSR control bits, detect the write and generate the corresponding
control behavior.

Example:

``` text
write CPSR with LD=1
        |
        v
generate aes_ld pulse
```

The AXI slave must return a valid write response through the B channel.

Support `WSTRB[3:0]` correctly for 32-bit writes.

------------------------------------------------------------------------

# 14. AXI Read Behavior

When the AXI master requests an address:

``` text
ARVALID & ARREADY
```

decode the address and return:

``` text
RDATA[31:0]
```

Examples:

``` text
0x00 -> CPSR
0x24 -> TEXT_OUT0
0x28 -> TEXT_OUT1
0x2C -> TEXT_OUT2
0x30 -> TEXT_OUT3
```

Return an appropriate AXI read response.

------------------------------------------------------------------------

# 15. Control Logic Requirements

The wrapper must translate software-visible CPSR control writes into AES
signals.

Minimum internal signals:

``` verilog
wire        aes_clk;
wire        aes_rst;
reg         aes_ld;
reg         aes_kld;
wire        aes_done;
wire        aes_kdone;

wire [127:0] aes_key;
wire [127:0] aes_text_in;
wire [127:0] aes_text_out;
```

For the forward core:

``` text
aes_ld  -> aes_cipher_top.ld
aes_done <- aes_cipher_top.done
```

For the inverse core:

``` text
aes_kld  -> aes_inv_cipher_top.kld
aes_kdone <- aes_inv_cipher_top.kdone

aes_ld   -> aes_inv_cipher_top.ld
aes_done <- aes_inv_cipher_top.done
```

Only instantiate/use the required AES datapath according to the selected
architecture.

------------------------------------------------------------------------

# 16. Important Question: Direct LD

Do NOT implement `LD` as a continuously asserted level if the AES core
expects a load pulse.

Recommended behavior:

``` text
AXI writes CPSR with LD=1
          |
          v
     aes_ld <= 1
          |
       one clock
          |
          v
     aes_ld <= 0
```

The software-visible CPSR bit may be read back according to the chosen
register semantics, but the internal AES control should generate the
required pulse.

Similarly for `KLD`.

Do not repeatedly trigger the AES core just because a software register
retains a `1`.

------------------------------------------------------------------------

# 17. Status Handling

`DONE` and `KDONE` originate from the AES core.

Recommended relationship:

``` text
aes_done  -> CPSR.DONE
aes_kdone -> CPSR.KDONE
```

Decide and document whether these status bits are:

1.  direct live reflections of the AES outputs, or
2.  latched status bits cleared by software.

For the first implementation, a simple live/reflected status behavior is
acceptable unless the existing software protocol requires latched
status.

Do not invent additional status semantics without a requirement.

------------------------------------------------------------------------

# 18. Reset

The supplied AES core defines:

``` text
rst = active-low synchronous reset
```

The AXI wrapper must provide a clean reset relationship.

If the AXI interface uses `s_axi_aresetn`, determine whether the wrapper
directly maps:

``` text
aes_rst = s_axi_aresetn
```

or whether an internal reset convention is required.

Be consistent throughout the design.

After reset:

``` text
KEY registers     = 0
TEXT_IN registers = 0
control pulses    = 0
CPSR status       = reset state
TEXT_OUT          = reset/known state if supported
```

Do not start AES automatically after reset.

------------------------------------------------------------------------

# 19. Recommended RTL File Structure

Keep the implementation modular:

``` text
rtl/
├── existing AES files
│   ├── aes_cipher_top.v
│   ├── aes_inv_cipher_top.v
│   ├── aes_inv_sbox.v
│   ├── aes_key_expand_128.v
│   ├── aes_rcon.v
│   ├── aes_sbox.v
│   └── timescale.v
│
├── aes_axi_slave.v
├── aes_reg_map.v
└── aes_axi_top.v
```

Suggested responsibilities:

## `aes_axi_slave.v`

Implement:

-   AXI4-Lite write channel
-   AXI4-Lite read channel
-   address/data handshake
-   write response
-   read response
-   register read/write strobes

## `aes_reg_map.v`

Implement:

-   CPSR
-   KEY0..KEY3
-   TEXT_IN0..TEXT_IN3
-   TEXT_OUT0..TEXT_OUT3
-   address decoding
-   control/status mapping

## `aes_axi_top.v`

Connect:

``` text
AXI slave
   |
register map
   |
AES control
   |
AES cipher/inverse cipher
```

------------------------------------------------------------------------

------------------------------------------------------------------------

# 22. Critical Design Constraints

1.  **Do not modify the existing AES algorithm unnecessarily.**
2.  Reuse the existing AES-128 cipher/inverse-cipher modules.
3.  Preserve the existing 128-bit key and text interfaces.
4.  AXI data width is 32 bits.
5.  Four registers are required for each 128-bit quantity.
6.  `LD` and `KLD` are AES control inputs.
7.  `DONE` and `KDONE` are AES status outputs.
8.  The CPSR must represent these AES signals as specified above.
9.  Do not create a separate COMMAND register unless a later requirement
    explicitly demands it.
10. `LD`/`KLD` must not accidentally retrigger the AES core every cycle.
11. Verify register functionality independently before integrating AES.
12. Verify AXI handshakes independently before debugging AES.
13. Verify AES with a known-good test vector after AXI/register
    functionality works.
14. Preserve the supplied AES byte/word ordering.
15. Do not assume waveform values; verify them from simulation.

------------------------------------------------------------------------

# 23. Final Target

The final system should behave like this:

``` text
                    AXI MASTER
                         |
                         | 32-bit read/write
                         v
              +-----------------------+
              |     AXI4-Lite SLAVE   |
              +-----------+-----------+
                          |
                  +-------v-------+
                  |     CPSR      |
                  |               |
                  | LD            |----> AES ld
                  | DONE <--------|<---- AES done
                  | KLD           |----> AES kld
                  | KDONE <-------|<---- AES kdone
                  | RST           |
                  | MODE          |
                  +---------------+
                          |
             +------------+------------+
             |                         |
             v                         v
       KEY0..KEY3                TEXT_IN0..3
             |                         |
             +------------+------------+
                          |
                       128-bit
                          |
                    +-----v-----+
                    | AES-128   |
                    | Core      |
                    +-----+-----+
                          |
                       128-bit
                          |
                    TEXT_OUT
                          |
                  +-------+-------+
                  |               |
             OUT0..OUT3       AXI MASTER
```

## 24. Immediate Implementation Order

Build in this exact order:

``` text
Step 1: AXI4-Lite slave
Step 2: Register address decoder
Step 3: CPSR
Step 4: KEY0..KEY3
Step 5: TEXT_IN0..TEXT_IN3
Step 6: TEXT_OUT0..TEXT_OUT3
Step 7: LD/KLD control pulse generation
Step 8: DONE/KDONE status connection
Step 9: Connect existing AES encryption core
Step 10: Connect existing AES inverse core
Step 11: AXI master testbench
Step 12: Encryption verification
Step 13: Decryption verification
Step 14: Verdi waveform verification
```

The first milestone should be:

``` text
AXI write -> register -> readback
```

The second:

``` text
AXI write -> AES control -> AES -> DONE -> AXI readback
```

Do not attempt to debug AXI protocol, register mapping, and AES
algorithm simultaneously.
