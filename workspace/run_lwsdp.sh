#!/bin/bash
set -e
BINDIR=/workspace/gpgpu-sim_simulations/benchmarks/src/cuda/bin/release
RESDIR=/workspace/results/lwsdp
ISPASS=/workspace/ispass2009-benchmarks

# CRITICAL: run from the config dir so GPGPU-Sim finds gpgpusim.config
cd $RESDIR

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a $RESDIR/run_master.log; }

run() {
    local name=$1; shift
    log "START $name"
    "$@" > $RESDIR/${name}.log 2>&1
    local ipc=$(grep "gpu_tot_ipc" $RESDIR/${name}.log | tail -1 | awk '{print $3}')
    log "DONE  $name  IPC=$ipc"
}

log "=== LWSDP run ==="

run BFS   $BINDIR/BFS  /workspace/gpgpu-sim_simulations/benchmarks/src/cuda/rodinia/3.1/data/bfs/graph65536.txt
run BFS2  $BINDIR/BFS2 $ISPASS/BFS/data/graph65536.txt
run BP    $BINDIR/BP   65536
run GA    $BINDIR/GA
run 3DC   $BINDIR/3DC
run LUD   $BINDIR/LUD  -s 256
run HS    $BINDIR/HS   512 512 2 /tmp/temp_512.txt /tmp/power_512.txt /tmp/hs_out.txt

# NN must run from its data directory
log "START NN"
(cd $ISPASS/NN && $BINDIR/NN 100 > $RESDIR/NN.log 2>&1)
ipc=$(grep "gpu_tot_ipc" $RESDIR/NN.log | tail -1 | awk '{print $3}')
log "DONE  NN  IPC=$ipc"

log "=== ALL DONE ==="
