#!/bin/bash
source /workspace/gpgpu-sim-dev/setup_environment

CUDA=nvcc
COMMON_INC=/workspace/gpgpu-sim_simulations/benchmarks/src/cuda/common/inc
COMMON_LIB=/workspace/gpgpu-sim_simulations/benchmarks/src/cuda/common/lib
BINDIR=/workspace/gpgpu-sim_simulations/benchmarks/src/cuda/bin/release
BASE=/workspace/gpgpu-sim_simulations/benchmarks/src/cuda
RODINIA=$BASE/rodinia/3.1/cuda
ISPASS=$BASE/ispass-2009
PANNOTIA=$BASE/pannotia

mkdir -p $BINDIR

NF="--cudart shared -arch=sm_30 -I$COMMON_INC -I. -L$COMMON_LIB -lcutil_x86_64"

ok=0; fail=0

build() {
    local name=$1; local dir=$2; local src=$3; local extra=$4
    echo -n "Building $name ... "
    cd $dir
    $CUDA $src $NF $extra -o $BINDIR/$name 2>/tmp/build_${name}.err \
        && { echo "OK"; ((ok++)); } \
        || { echo "FAILED -- $(grep 'error:' /tmp/build_${name}.err | head -1)"; ((fail++)); }
    cd - > /dev/null
}

# ISPASS-2009
build "BFS"  $ISPASS/BFS  "bfs.cu"          "-I."
build "NN"   $ISPASS/NN   "NN.cu"            "-I."
build "LPS"  $ISPASS/LPS  "laplace3d.cu"     "-I."
build "MUM"  $ISPASS/MUM  "mummergpu.cu common.cu mummergpu_gold.cpp mummergpu_main.cpp suffix-tree.cpp PoolMalloc.cpp" "-I. -lstdc++"

# Rodinia
build "HS"   $RODINIA/hotspot   "hotspot.cu"              ""
build "GA"   $RODINIA/gaussian  "gaussian.cu"             ""
build "BFS2" $RODINIA/bfs       "bfs.cu"                  "-I."
build "NN2"  $RODINIA/nn        "nn_cuda.cu"              "-I."
build "BP"   $RODINIA/backprop  "backprop_cuda.cu backprop.c facetrain.c imagenet.c" "-I."
build "LUD"  $RODINIA/lud/cuda  "lud.cu"                  "-I. -I../common"
build "KMN"  $RODINIA/kmeans    "kmeans_cuda.cu kmeans_clustering.c kmeans.c cluster.c getopt.c rmse.c" "-I."

# B+Tree (complex - multiple files)
echo -n "Building BPLUS ... "
cd $RODINIA/b+tree
$CUDA main.c \
    kernel/kernel_gpu_cuda_wrapper.cu \
    kernel/kernel_gpu_cuda_wrapper_2.cu \
    $NF -I. -Ikernel \
    -o $BINDIR/BPLUS 2>/tmp/build_BPLUS.err \
    && { echo "OK"; ((ok++)); } \
    || { echo "FAILED -- $(grep 'error:' /tmp/build_BPLUS.err | head -2)"; ((fail++)); }
cd - > /dev/null

# Pannotia
build "FW"   $PANNOTIA/fw   "Floyd-Warshall.cu kernel.cu"  "-I. -I$PANNOTIA/common"
build "MIS"  $PANNOTIA/mis  "mis.cu kernel.cu"             "-I. -I$PANNOTIA/common"

# Polybench
build "3DC"  $BASE/polybench-gpu-1.0/CUDA/3DCONV  "3DConvolution.cu"  ""

echo ""
echo "============================================"
echo " Built: $ok OK,  $fail FAILED"
echo " Binaries:"
ls $BINDIR
echo "============================================"
