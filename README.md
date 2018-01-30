# Vypec
VHDL acceleration for Jypec (https://github.com/Daniel-BG/Jypec)

Implementation of the Block Coding found in JPEG2000 [1]. This aims to accelerate execution times of the Jypec algorithm, since profiling shows that block coding amounts to ~40-70% of the total execution time. FPGAs, and their ability to quickly process raw bit data, the core of the block coding, can accelerate this bottleneck.


# References

[1] Joint photographic experts group. "JPEG2000." https://jpeg.org/jpeg2000/


# Sources for VHDL modules

The STD_FIFO module is free of copyright, you can see the source here

http://www.deathbylogic.com/2013/07/vhdl-standard-fifo/


Two additional external modules are required. The RX and TX modules of the UART protocol. They can be downloaded from the NandLand Website.

https://www.nandland.com/vhdl/modules/module-uart-serial-port-rs232.html