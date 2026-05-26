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
CMD_QUICK_STOP      = 0x0002  # → Quick Stop Active (bit2=0 asserts quick stop)
CMD_FAULT_RESET     = 0x0080

# Statusword state mask: DS402 bits 6,5,3,2,1,0 define the state machine.
# Bits 4 (voltage enabled), 7 (warning), 9 (remote) etc. are informational
# and must be masked out before comparing against state values.
SW_MASK = 0x006F
SW_SWITCH_ON_DISABLED = 0x0040  # LC10E: 0x0250
SW_READY_TO_SWITCH_ON = 0x0021  # LC10E: 0x0231
SW_SWITCHED_ON        = 0x0023  # LC10E: 0x0233
SW_OPERATION_ENABLED  = 0x0027  # LC10E: 0x0237
SW_QUICK_STOP_ACTIVE  = 0x0007  # LC10E: 0x0217 ("Fast stop")
SW_FAULT_BIT          = 0x0008

h = hal.component('cia402-sm')
h.newpin('statusword', hal.HAL_U32, hal.HAL_IN)
h.newpin('enable',     hal.HAL_BIT, hal.HAL_IN)
h.newpin('controlword', hal.HAL_U32, hal.HAL_OUT)
h.newpin('enabled',    hal.HAL_BIT, hal.HAL_OUT)
h.newpin('fault',      hal.HAL_BIT, hal.HAL_OUT)
h.ready()

def sdo_write(obj_type, idx, subidx, value, retries=20):
    cmd = ['ethercat', '-p', '0', 'download', '--type', obj_type, idx, subidx, str(value)]
    for attempt in range(retries):
        r = subprocess.run(cmd, capture_output=True)
        if r.returncode == 0:
            return True
        time.sleep(0.1)
    raise RuntimeError(f'SDO write failed after {retries} attempts: {idx}:{subidx} = {value}')

# Parameters applied at every startup.
# Drive persists 2000h params to EEPROM (200C:0Eh=3), but we write them here too
# so the config is self-documenting and survives a factory reset.

# Electronic gear ratio: 8388608:10000 → 1 cmd unit = 1 micron (23-bit encoder, 10mm screw)
sdo_write('uint32', '0x6091', '0x01', '8388608')
sdo_write('uint32', '0x6091', '0x02', '10000')

# Speed feedforward source: 1 = internal (drive computes from consecutive position targets)
# Must be set before enable (stop setting).
sdo_write('uint16', '0x2005', '0x14', '1')

# Max speed cap: 500mm/s in cmd units. Motor max = 2500RPM × 10mm pitch = 416667 cmd/s.
sdo_write('uint32', '0x607f', '0x00', '500000')

# Drive-side position deviation alarm: widened to 500mm for slow quick-stop ramp testing.
# Restore to 20000 (20mm, matching LinuxCNC FERROR) once tuning is complete.
sdo_write('uint32', '0x6065', '0x00', '500000')

# Quick stop: decelerate on quick-stop ramp then auto-transition to Switch On Disabled.
# 605A=3 means no controlword needed after decel — drive lands in Servo no faults (0x0250).
sdo_write('uint16', '0x605A', '0x00', '3')
# Quick stop deceleration: 20 mm/s² = 20000 cmd units/s² — slow ramp for human observation.
# Restore to 500000 (500 mm/s², matching joint MAX_ACCELERATION) after testing.
sdo_write('uint32', '0x6085', '0x00', '20000')

# Speed loop: bandwidth (stored ×10, range 0.1~200.0Hz, max stored = 2000).
# Integration time scaled proportionally: new = old × (old_BW / new_BW).
# Default was 25.0Hz / 31.83ms.
sdo_write('uint16', '0x2008', '0x01', '500')   # 50Hz (2× default)
sdo_write('uint16', '0x2008', '0x02', '1600')  # 16ms (31.83ms × 25/50)

# Position loop: 80Hz (2× default of 40Hz).
sdo_write('uint16', '0x2008', '0x03', '800')

# Speed feedforward filter: 0.50ms (stored ×100 = 50). Default.
sdo_write('uint16', '0x2008', '0x13', '50')

# Torque feedforward: gain disabled (0), filter 0.50ms. Not used in internal-FF mode.
sdo_write('uint16', '0x2008', '0x16', '0')
sdo_write('uint16', '0x2008', '0x15', '50')

# Torque command filter: 0.79ms (stored ×100 = 79). Default.
sdo_write('uint16', '0x2007', '0x06', '79')

feedforward_applied = False

try:
    while True:
        sw     = h['statusword'] & 0xFFFF
        enable = h['enable']
        state  = sw & SW_MASK
        fault  = bool(sw & SW_FAULT_BIT)

        if fault:
            feedforward_applied = False
            h['controlword'] = CMD_FAULT_RESET if enable else CMD_DISABLE_VOLTAGE
            h['enabled'] = False
            h['fault']   = True
        elif state == SW_QUICK_STOP_ACTIVE:
            # Hold CMD_QUICK_STOP while the drive decelerates on the quick-stop ramp.
            # With 605A=3 the drive auto-transitions to Switch On Disabled when done —
            # no further controlword needed from us.
            h['controlword'] = CMD_QUICK_STOP
            h['enabled'] = False
            h['fault']   = False
        elif not enable:
            if state == SW_OPERATION_ENABLED:
                # Controlled stop: let the drive decel on its quick-stop ramp.
                h['controlword'] = CMD_QUICK_STOP
            else:
                # Not running — just drop to disabled immediately.
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
            if not feedforward_applied:
                sdo_write('uint16', '0x2008', '0x14', '1000')
                feedforward_applied = True
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
