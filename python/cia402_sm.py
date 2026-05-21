#!/usr/bin/env python3
"""CiA 402 state machine HAL component for LC10E servo drive.

Watches the drive statusword and drives the controlword through the
enable sequence.  Runs as a userspace HAL component at ~100 Hz.
"""
import hal
import time
import subprocess

# Controlword commands (DS402 table 20)
CMD_DISABLE_VOLTAGE = 0x0000
CMD_SHUTDOWN        = 0x0006  # → Ready to switch on
CMD_SWITCH_ON       = 0x0007  # → Switched on
CMD_ENABLE_OP       = 0x000F  # → Operation enabled
CMD_FAULT_RESET     = 0x0080

# Statusword state mask (bits 6,5,3,2,1,0)
SW_MASK = 0x006F
SW_SWITCH_ON_DISABLED = 0x0040
SW_READY_TO_SWITCH_ON = 0x0021
SW_SWITCHED_ON        = 0x0023
SW_OPERATION_ENABLED  = 0x0027
SW_FAULT_BIT          = 0x0008

h = hal.component('cia402-sm')
h.newpin('statusword', hal.HAL_U32, hal.HAL_IN)
h.newpin('enable',     hal.HAL_BIT, hal.HAL_IN)
h.newpin('controlword', hal.HAL_U32, hal.HAL_OUT)
h.newpin('enabled',    hal.HAL_BIT, hal.HAL_OUT)
h.newpin('fault',      hal.HAL_BIT, hal.HAL_OUT)
h.ready()

# Gear ratio 8388608:10000 = 1 cmd unit = 1 micron; drive resets to 1:1 on power cycle
subprocess.run(['ethercat', '-p', '0', 'download', '--type', 'uint32', '0x6091', '0x01', '8388608'])
subprocess.run(['ethercat', '-p', '0', 'download', '--type', 'uint32', '0x6091', '0x02', '10000'])

try:
    while True:
        sw     = h['statusword'] & 0xFFFF
        enable = h['enable']
        state  = sw & SW_MASK
        fault  = bool(sw & SW_FAULT_BIT)

        if fault:
            h['controlword'] = CMD_FAULT_RESET if enable else CMD_DISABLE_VOLTAGE
            h['enabled'] = False
            h['fault']   = True
        elif not enable:
            h['controlword'] = CMD_DISABLE_VOLTAGE
            h['enabled'] = False
            h['fault']   = False
        elif state == SW_SWITCH_ON_DISABLED:
            h['controlword'] = CMD_SHUTDOWN
            h['enabled'] = False
            h['fault']   = False
        elif state == SW_READY_TO_SWITCH_ON:
            h['controlword'] = CMD_SWITCH_ON
            h['enabled'] = False
            h['fault']   = False
        elif state == SW_SWITCHED_ON:
            h['controlword'] = CMD_ENABLE_OP
            h['enabled'] = False
            h['fault']   = False
        elif state == SW_OPERATION_ENABLED:
            h['controlword'] = CMD_ENABLE_OP
            h['enabled'] = True
            h['fault']   = False
        else:
            h['controlword'] = CMD_SHUTDOWN
            h['enabled'] = False
            h['fault']   = False

        time.sleep(0.01)
except KeyboardInterrupt:
    pass
