/* =============================================================================
 * Linker script for VeeR-EL2 CNN SoC
 * IMEM: 0x0000_0000 (64 KB)
 * DMEM: 0x1000_0000 (64 KB)
 * ============================================================================= */

OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
  IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
  DMEM (rwx) : ORIGIN = 0x10000000, LENGTH = 64K
}

SECTIONS
{
  .text : {
    . = ALIGN(4);
    KEEP(*(.text.init))
    *(.text .text.*)
    *(.rodata .rodata.*)
    . = ALIGN(4);
    _etext = .;
  } > IMEM

  _sidata = LOADADDR(.data);

  .data : AT(_etext) {
    . = ALIGN(4);
    _sdata = .;
    *(.data .data.*)
    *(.sdata .sdata.*)
    . = ALIGN(4);
    _edata = .;
  } > DMEM

  .bss : {
    . = ALIGN(4);
    _sbss = .;
    *(.bss .bss.*)
    *(.sbss .sbss.*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > DMEM

  .stack (NOLOAD) : {
    . = ALIGN(16);
    . = . + 0x2000; /* 8 KB Stack */
    _stack_top = .;
  } > DMEM
}
