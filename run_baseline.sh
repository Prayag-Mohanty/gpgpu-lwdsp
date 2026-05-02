#!/bin/bash
source /workspace/gpgpu-sim-dev/setup_environment

BINDIR=/workspace/gpgpu-sim_simulations/benchmarks/src/cuda/bin/release
RESULTS=/workspace/results/baseline
CONFIG=/workspace/gpgpu-sim-dev/configs/tested-cfgs/SM7_TITANV
ISPASS_DATA=/workspace/ispass2009-benchmarks
RODINIA_DATA=/workspace/gpgpu-sim_simulations/benchmarks/src/cuda/rodinia/3.1/data

mkdir -p $RESULTS
cp $CONFIG/gpgpusim.config $RESULTS/
cp $CONFIG/config_volta_islip.icnt $RESULTS/
cd $RESULTS

run_bench() {
    local name=$1
    local cmd=$2
    echo "=============================="
    echo "Running $name ... $(date)"
    echo "=============================="
    eval "$cmd" > ${name}.log 2>&1
    echo "--- $name done. Key stats: ---"
    grep -E "gpu_tot_ipc|L1D_total_cache_miss_rate|gpgpu_n_stall_shd_mem" ${name}.log | tail -5
    echo ""
}

# ISPASS
run_bench "BFS"  "$BINDIR/BFS $ISPASS_DATA/BFS/data/graph65536.txt"
run_bench "NN"   "$BINDIR/NN $ISPASS_DATA/NN/data/filelist_4 -r 5 -lat 50 -lons 50"

# Rodinia
run_bench "HS"   "$BINDIR/HS 512 512 2 $RODINIA_DATA/hotspot/temp_512 $RODINIA_DATA/hotspot/power_512 /tmp/hs_out.txt"
run_bench "BP"   "$BINDIR/BP 65536"
run_bench "GA"   "$BINDIR/GA -s 128"
run_bench "KMN"  "$BINDIR/KMN -o -d 34 -c 5 -p 2048 -f $RODINIA_DATA/kmeans/kdd_cup"
run_bench "NN2"  "$BINDIR/NN2 $RODINIA_DATA/nn/filelist_4 -r 5 -lat 50 -lons 50"
run_bench "BFS2" "$BINDIR/BFS2 $RODINIA_DATA/bfs/graph1MW_6.txt"
run_bench "3DC"  "$BINDIR/3DC"

echo "=============================="
echo "ALL DONE — $(date)"
echo ""
echo "=== IPC SUMMARY ==="
grep "gpu_tot_ipc" $RESULTS/*.log

echo ""
echo "=== L1D MISS RATE SUMMARY ==="
grep "L1D_total_cache_miss_rate" $RESULTS/*.log

echo ""
echo "=== STALL SUMMARY ==="
grep "gpgpu_n_stall_shd_mem" $RESULTS/*.log
echo "=============================="
