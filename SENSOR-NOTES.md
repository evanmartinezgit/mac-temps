# M1 Max sensor names

Catalog researched for MacBookPro18,2 (M1 Max). Keys are case-sensitive. It is disabled on other model identifiers, where readings retain unknown labels.

## Evidence

- Stats, M1-generation and Apple Silicon temperature entries: https://github.com/exelban/stats/blob/master/Modules/Sensors/values.swift
- iSMC, Apple-platform temperature descriptions: https://github.com/dkorunic/iSMC/blob/master/smc/sensors.go
- Cross-check that reveals conflicting descriptions (tested on M2, not this machine): https://github.com/ryyansafar/MacMonitor/blob/main/SENSORS.md

Retrieved September 21, 2026. These are community catalogs, not an Apple sensor specification. The native SMC interface exposes IDs, not an authoritative location dictionary.

## Status meanings

- **Community mapped:** an exact M1 or general Apple Silicon entry in Stats. 24 of this machine's 238 discovered keys match: 10 CPU cores, 4 GPU groups, 4 memory channels, 2 battery channels, 2 airflow channels, NAND flash and Wi-Fi. Only these entries feed the CPU/GPU/battery headline values.
- **Tentative:** an iSMC Apple-platform description that has not been verified on this M1 Max, or a clearly identified family inference for unnamed Tp/Tg/Tm channels. No inferred core numbering is used.
- **Disputed:** sources assign incompatible meanings to the key/family (notably TPD/TRD/TD/TV). The displayed name remains unresolved; the proposed iSMC description appears in the tooltip. This avoids misidentifying a power-management or virtual reading as a physical CPU/GPU sensor.
- **Unknown:** no defensible mapping found. The original ID is retained.

A channel can be a derived/aggregate value rather than a separate physical sensor. No stress experiments were used to invent physical locations. Temperature decoding and sampling are unchanged. CSV export includes name and mapping status. Session peaks restart when the app restarts.

Build: `./build.sh` (Apple command-line tools required).
