LAVC was implemented within GPGPUSim v4.0, a cycle-accurate GPU microarchitec-
ture simulator widely used in academic research. The implementation required modifica-
tions to two primary source files: shader.cc (warp scheduler) and gpu-cache.cc/gpu-cache.h
(cache hierarchy). A new module, victim cache.cc, was added to encapsulate the VTT
and load monitor logic.
5.1 Simulator Configuration
The GV100 configuration file was modified to enable the LAVC features via configuration
flags:
• -gpgpu l1 victim cache 1: Enables the Linebacker victim cache. Sets the VTT
to 4-way, 48 sets; allocates register file entries 1024–2047 as the SUR-mapped vic-
tim data array (VDA). The monitoring period is 50,000 cycles and the hit-ratio
threshold is 0.20.
• -gpgpu locality scheduler 1: Enables the LWS. Configures the intra-warp lo-
cality threshold at 2 mfs per prefetch block and inter-warp threshold at 2 warps
per block. Score decay period is 25,000 cycles.
• -gpgpu victim cache sets 48: Sets VTT set count equal to L1D set count.
• -gpgpu victim cache ways 4: Sets VTT associativity.
5.2 Warp Scheduler Modifications (shader.cc)
The scheduler unit class was extended with the following additions:
• A per-warp score array (m locality score[MAX WARPS]) of 8-bit unsigned integers,
initialised to zero at kernel launch.
• A locality detector method that queries the MSHR at each miss event, identifies
prefetch blocks with two or more recorded miss entries, and increments the scores
of all warps whose mfs map to the same block.
16
• A modified cycle() method that sorts the candidate warp list by {is memory warp
DESC, m locality score DESC, warp age ASC} before selecting the next warp to
issue. Tie-breaking falls back to the original GTO ordering.
• A score decay() method invoked every 25,000 cycles that right-shifts all scores
by one bit (halving them), preventing old locality information from perpetually
dominating scheduling.
5.3 Victim Cache Implementation (victim cache.cc)
The VictimCache class encapsulates:
• VTT: A 4-way set-associative tag array with 48 sets, implemented as a 2D array
of VTTEntry structs containing {valid, tag, lru state, register number}.
• LoadMonitor: A 32-entry table indexed by 5-bit hashed PC, storing {hit count,
miss count, valid[2]} per load. Updated at every L1D hit or miss from the
arbitrator’s access log.
• SUR allocator: Tracks which warp register numbers (1024–2047) are unused.
Assigns register numbers to VTT entries on insertion and reclaims them on VTT
eviction.
• probe(addr): Returns a VTTEntry if addr hits in the VTT, null otherwise.
• fill(addr, line): Inserts addr into the VTT, writing the cache line into the
corresponding register file entry via a register-file write request injected into the
arbitrator.
5.4 Integration with the Memory Pipeline (gpu-cache.cc)
The existing L1D access path in ldst unit::process memory access() was extended
to call victim cache.probe() on an L1D miss, prior to issuing the L2 request. A VTT
hit returns a VICTIM HIT status, which causes the pipeline to:
• Read the compressed line from the appropriate register-file bank via the arbitrator.
• Write the decompressed data to the destination register(s) of the requesting warp.
• Increment the Load Monitor’s hit counter for the requesting load’s PC.
• Update the VTT LRU state for the hit set.
On an L1D eviction, the evicted line’s load PC is checked against the Load Mon-
itor. If the load is classified as high-locality (valid[0] AND valid[1] both set),
victim cache.fill() is called with the evicted address and data. Otherwise, the line is
discarded as per the original LRU eviction policy
