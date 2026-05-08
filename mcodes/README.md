# mcodes

User M-codes (M100–M199). Each file is named MXXX.ngc and runs when LinuxCNC encounters that M-code.

M100 - pre-flight tool check. Add as first line of every program. Scans for T words and aborts if any tool has no rack position (P0).
