#!/usr/bin/env python3
"""Read all known LC10E parameters from drive and compare to defaults."""
import csv
import subprocess
import sys

CSV_PATH = 'documents/lc10e_params_2000h.csv'
SLAVE = '0'

def ethercat_upload(index, subindex, typ):
    result = subprocess.run(
        ['ethercat', '-p', SLAVE, 'upload', '--type', typ, index, subindex],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return None
    # output is like "0x0064 100\n" or "100\n"
    parts = result.stdout.strip().split()
    if len(parts) >= 2:
        return parts[-1]  # decimal value
    return result.stdout.strip()

TYPE_MAP = {
    'Uint16': 'uint16',
    'Int16':  'int16',
    'Uint32': 'uint32',
    'Int32':  'int32',
}

rows = []
with open(CSV_PATH) as f:
    for row in csv.DictReader(f):
        rows.append(row)

print(f"{'Param':<8} {'Name':<52} {'Default':<10} {'Current':<10} {'!'}")
print('-' * 90)

for row in rows:
    typ = TYPE_MAP.get(row['type'])
    if typ is None:
        continue

    value = ethercat_upload(row['index'], row['subindex'], typ)
    default = row['default'].strip()

    flag = ''
    try:
        if default not in ('-', '') and value is not None:
            if int(value) != int(default):
                flag = '<--'
    except ValueError:
        pass

    status = value if value is not None else 'ERR'
    print(f"{row['param']:<8} {row['name'][:52]:<52} {default:<10} {status:<10} {flag}")
