# Locality-Aware Victim Cache (LAVC)

LAVC was implemented within **GPGPU-Sim v4.0**, a cycle-accurate GPU microarchitecture simulator widely used in academic research.  
The implementation required modifications to two primary source files:

- `shader.cc` (warp scheduler)  
- `gpu-cache.cc` / `gpu-cache.h` (cache hierarchy)  

Additionally, a new module `victim_cache.cc` was added to encapsulate the **Victim Tag Table (VTT)** and **Load Monitor** logic.

---

## 5.1 Simulator Configuration

The GV100 configuration file was modified to enable LAVC features via configuration flags:

- `-gpgpu_l1_victim_cache 1`  
  Enables the Linebacker victim cache.  
  - VTT: 4-way, 48 sets  
  - SUR-mapped victim data array (VDA): register file entries 1024–2047  
  - Monitoring period: 50,000 cycles  
  - Hit-ratio threshold: 0.20  

- `-gpgpu_locality_scheduler 1`  
  Enables the Locality-Aware Warp Scheduler (LWS).  
  - Intra-warp locality threshold: 2 mfs per prefetch block  
  - Inter-warp threshold: 2 warps per block  
  - Score decay period: 25,000 cycles  

- `-gpgpu_victim_cache_sets 48`  
  Sets VTT set count equal to L1D set count.  

- `-gpgpu_victim_cache_ways 4`  
  Sets VTT associativity.  

---

## 5.2 Warp Scheduler Modifications (`shader.cc`)

The scheduler unit class was extended with:

- **Per-warp score array**: `m_locality_score[MAX_WARPS]` (8-bit unsigned integers, initialized to zero at kernel launch).  
- **Locality detector**: Queries the MSHR at each miss event, identifies prefetch blocks with ≥2 miss entries, increments scores of all warps mapping to that block.  
- **Modified `cycle()` method**: Sorts candidate warp list by `{is_memory_warp DESC, m_locality_score DESC, warp_age ASC}` before issuing. Tie-breaking falls back to GTO ordering.  
- **Score decay**: Invoked every 25,000 cycles, right-shifts all scores by one bit (halving them).  

---

## 5.3 Victim Cache Implementation (`victim_cache.cc`)

The `VictimCache` class encapsulates:

- **VTT**: 4-way set-associative tag array with 48 sets.  
  - Implemented as 2D array of `VTTEntry` structs `{valid, tag, lru_state, register_number}`.  

- **LoadMonitor**: 32-entry table indexed by 5-bit hashed PC.  
  - Stores `{hit_count, miss_count, valid[2]}` per load.  
  - Updated at every L1D hit/miss.  

- **SUR allocator**: Tracks unused warp register numbers (1024–2047).  
  - Assigns registers to VTT entries on insertion, reclaims them on eviction.  

- **Methods**:  
  - `probe(addr)`: Returns `VTTEntry` if addr hits, null otherwise.  
  - `fill(addr, line)`: Inserts addr into VTT, writes cache line into register file entry via arbitrator.  

---

## 5.4 Integration with Memory Pipeline (`gpu-cache.cc`)

The L1D access path in `ldst_unit::process_memory_access()` was extended:

- On **L1D miss**:  
  - Calls `victim_cache.probe()` before issuing L2 request.  
  - On VTT hit:  
    - Reads compressed line from register-file bank via arbitrator.  
    - Writes decompressed data to destination registers.  
    - Increments Load Monitor hit counter.  
    - Updates VTT LRU state.  

- On **L1D eviction**:  
  - Checks evicted line’s load PC against Load Monitor.  
  - If classified as high-locality (`valid[0] && valid[1]`):  
    - Calls `victim_cache.fill()` with evicted address and data.  
  - Otherwise:  
    - Discards line per original LRU policy.  
