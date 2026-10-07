#!/bin/bash
# Baut yskar-cuda fuer Linux. Laeuft im nvidia/cuda-devel-Container.
# /src = node-core/gpu (nur lesen), /out = Ergebnis
set -euo pipefail
cd /tmp
known=$(nvcc --list-gpu-arch | sed -n 's/^compute_\([0-9]*\)$/\1/p')
gencode=()
max=0
for a in 50 52 60 61 70 75 80 86 89 90 100 120; do
  if echo "$known" | grep -qx "$a"; then
    gencode+=("-gencode=arch=compute_$a,code=sm_$a")
    max=$a
  fi
done
gencode+=("-gencode=arch=compute_$max,code=compute_$max")
echo "nvcc: $(nvcc --version | tail -1)"
echo "archs: ${gencode[*]}"
nvcc "${gencode[@]}" -O3 -c -o gpu.o /src/yskar_gpu.cu
g++ -O2 -std=c++17 -c -o host.o /src/yskar_host.cpp
g++ -o /out/yskar-cuda gpu.o host.o -static-libstdc++ -static-libgcc \
  -L/usr/local/cuda/lib64 -lcudart_static -lpthread -ldl -lrt
strip /out/yskar-cuda
ls -la /out/yskar-cuda
ldd /out/yskar-cuda
objdump -T /out/yskar-cuda | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1
