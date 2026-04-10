#!/bin/bash
set -e
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     FLUX Benchmark Suite — Oracle Cloud ARM64 (4-core)     ║"
echo "║     Task: Factorial(20) + Fibonacci(30) + Sum(1..1000)     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

RESULTS="/tmp/flux-benchmarks/results.txt"
> $RESULTS

# ── 1. FLUX C VM (bytecode) ──
echo "=== 1. FLUX C VM (Direct Bytecode) ==="
cat > bench_flux.c << 'EOF'
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib>
#include <time.h>
#include <sys/resource.h>

/* Embedded FLUX VM */
#define FLUX_REGS 16
typedef struct { int32_t gp[FLUX_REGS]; uint32_t pc; int running, halted; uint64_t cycles; } FVM;
static uint8_t f8(FVM*v,uint8_t*bc){return bc[v->pc++];}
static int16_t fi16(FVM*v,uint8_t*bc){int16_t r=(int16_t)(bc[v->pc]|(bc[v->pc+1]<<8));v->pc+=2;return r;}

static int flux_run(FVM*v,uint8_t*bc,uint32_t len){
    v->running=1;v->halted=0;v->cycles=0;
    while(v->running&&v->pc<len&&v->cycles<100000000){
        uint8_t op=bc[v->pc++]; v->cycles++;
        switch(op){
            case 0x01:{uint8_t d=f8(v,bc),s=f8(v,bc);v->gp[d]=v->gp[s];break;}
            case 0x08:{uint8_t d=f8(v,bc),s=f8(v,bc);v->gp[d]+=v->gp[s];break;}
            case 0x09:{uint8_t d=f8(v,bc),s=f8(v,bc);v->gp[d]-=v->gp[s];break;}
            case 0x0A:{uint8_t d=f8(v,bc),s=f8(v,bc);v->gp[d]*=v->gp[s];break;}
            case 0x0E:{uint8_t d=f8(v,bc);v->gp[d]++;break;}
            case 0x0F:{uint8_t d=f8(v,bc);v->gp[d]--;break;}
            case 0x2B:{uint8_t d=f8(v,bc);v->gp[d]=fi16(v,bc);break;}
            case 0x06:{uint8_t d=f8(v,bc);int16_t off=fi16(v,bc);if(v->gp[d]!=0)v->pc+=off;break;}
            case 0x80:v->halted=1;v->running=0;break;
        }
    }
    return 0;
}

int main(){
    struct rusage ru;
    struct timespec start,end;
    
    /* Factorial 20 */
    uint8_t fact[]={
        0x2B,0x03,0x14,0x00, /* MOVI R3, 20 */
        0x2B,0x04,0x01,0x00, /* MOVI R4, 1 */
        0x0A,0x04,0x03,      /* IMUL R4, R3 */
        0x0F,0x03,           /* DEC R3 */
        0x06,0x03,0xF7,0xFF, /* JNZ R3, -9 */
        0x80                 /* HALT */
    };
    
    /* Fibonacci 30 */
    uint8_t fib[]={
        0x2B,0x00,0x00,0x00, /* MOVI R0, 0 */
        0x2B,0x01,0x01,0x00, /* MOVI R1, 1 */
        0x2B,0x02,0x1E,0x00, /* MOVI R2, 30 */
        0x01,0x03,0x01,      /* MOV R3, R1 */
        0x08,0x01,0x00,      /* IADD R1, R0 */
        0x01,0x00,0x03,      /* MOV R0, R3 */
        0x0F,0x02,           /* DEC R2 */
        0x06,0x02,0xF7,0xFF, /* JNZ R2, -9 */
        0x80
    };
    
    /* Sum 1..1000 */
    uint8_t sum[]={
        0x2B,0x00,0x00,0x00, /* MOVI R0, 0 */
        0x2B,0x01,0xE8,0x03, /* MOVI R1, 1000 */
        0x08,0x00,0x01,      /* IADD R0, R1 */
        0x0F,0x01,           /* DEC R1 */
        0x06,0x01,0xF7,0xFF, /* JNZ R1, -9 */
        0x80
    };
    
    int ITERS=100000;
    
    /* Factorial benchmark */
    clock_gettime(CLOCK_MONOTONIC,&start);
    for(int i=0;i<ITERS;i++){
        FVM v;memset(&v,0,sizeof(v));
        flux_run(&v,fact,sizeof(fact));
    }
    clock_gettime(CLOCK_MONOTONIC,&end);
    double fact_time=(end.tv_sec-start.tv_sec)+(end.tv_nsec-start.tv_nsec)/1e9;
    
    /* Fibonacci benchmark */
    clock_gettime(CLOCK_MONOTONIC,&start);
    for(int i=0;i<ITERS;i++){
        FVM v;memset(&v,0,sizeof(v));
        flux_run(&v,fib,sizeof(fib));
    }
    clock_gettime(CLOCK_MONOTONIC,&end);
    double fib_time=(end.tv_sec-start.tv_sec)+(end.tv_nsec-start.tv_nsec)/1e9;
    
    /* Sum benchmark */
    clock_gettime(CLOCK_MONOTONIC,&start);
    for(int i=0;i<ITERS;i++){
        FVM v;memset(&v,0,sizeof(v));
        flux_run(&v,sum,sizeof(sum));
    }
    clock_gettime(CLOCK_MONOTONIC,&end);
    double sum_time=(end.tv_sec-start.tv_sec)+(end.tv_nsec-start.tv_nsec)/1e9;
    
    /* Verify results */
    FVM vf;memset(&vf,0,sizeof(vf));flux_run(&vf,fact,sizeof(fact));
    FVM vb;memset(&vb,0,sizeof(vb));flux_run(&vb,fib,sizeof(fib));
    FVM vs;memset(&vs,0,sizeof(vs));flux_run(&vs,sum,sizeof(sum));
    
    printf("FLUX C VM Results (100K iterations each):\n");
    printf("  Factorial(20) = %d (expect 2432902008) [truncated i16] | %.3f ms total | %.0f ns/iter\n",
        vf.gp[4], fact_time*1000, fact_time*1e9/ITERS);
    printf("  Fibonacci(30) = %d | %.3f ms total | %.0f ns/iter\n",
        vb.gp[1], fib_time*1000, fib_time*1e9/ITERS);
    printf("  Sum(1..1000)  = %d (expect 500500) | %.3f ms total | %.0f ns/iter\n",
        vs.gp[0], sum_time*1000, sum_time*1e9/ITERS);
    printf("  Total: %.3f ms\n", (fact_time+fib_time+sum_time)*1000);
    printf("\n");
    return 0;
}
EOF
gcc -std=c11 -O2 -o bench_flux bench_flux.c -lm
echo "--- FLUX C VM ---"
./bench_flux
./bench_flux >> $RESULTS

# ── 2. Native C ──
echo "=== 2. Native C ==="
cat > bench_native.c << 'EOF'
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

int main(){
    struct timespec start,end;
    int ITERS=100000;
    int64_t fact_result=0, fib_result=0, sum_result=0;
    
    /* Factorial 20 */
    clock_gettime(CLOCK_MONOTONIC,&start);
    for(int i=0;i<ITERS;i++){
        int64_t r=1;for(int n=2;n<=20;n++)r*=n;
        fact_result=r;
    }
    clock_gettime(CLOCK_MONOTONIC,&end);
    double fact_time=(end.tv_sec-start.tv_sec)+(end.tv_nsec-start.tv_nsec)/1e9;
    
    /* Fibonacci 30 */
    clock_gettime(CLOCK_MONOTONIC,&start);
    for(int i=0;i<ITERS;i++){
        int64_t a=0,b=1;
        for(int n=0;n<30;n++){int64_t t=b;b=a+b;a=t;}
        fib_result=b;
    }
    clock_gettime(CLOCK_MONOTONIC,&end);
    double fib_time=(end.tv_sec-start.tv_sec)+(end.tv_nsec-start.tv_nsec)/1e9;
    
    /* Sum 1..1000 */
    clock_gettime(CLOCK_MONOTONIC,&start);
    for(int i=0;i<ITERS;i++){
        int64_t s=0;for(int n=1;n<=1000;n++)s+=n;
        sum_result=s;
    }
    clock_gettime(CLOCK_MONOTONIC,&end);
    double sum_time=(end.tv_sec-start.tv_sec)+(end.tv_nsec-start.tv_nsec)/1e9;
    
    printf("Native C Results (100K iterations each):\n");
    printf("  Factorial(20) = %ld | %.3f ms total | %.1f ns/iter\n",
        fact_result, fact_time*1000, fact_time*1e9/ITERS);
    printf("  Fibonacci(30) = %ld | %.3f ms total | %.1f ns/iter\n",
        fib_result, fib_time*1000, fib_time*1e9/ITERS);
    printf("  Sum(1..1000)  = %ld | %.3f ms total | %.1f ns/iter\n",
        sum_result, sum_time*1000, sum_time*1e9/ITERS);
    printf("  Total: %.3f ms\n", (fact_time+fib_time+sum_time)*1000);
    printf("\n");
    return 0;
}
EOF
gcc -std=c11 -O2 -o bench_native bench_native.c -lm
echo "--- Native C ---"
./bench_native
./bench_native >> $RESULTS

# ── 3. Python ──
echo "=== 3. Python ==="
python3 << 'PY'
import time

ITERS = 100000

# Factorial 20
t0 = time.monotonic()
for _ in range(ITERS):
    r = 1
    for n in range(2, 21): r *= n
fact_result = r
fact_time = time.monotonic() - t0

# Fibonacci 30
t0 = time.monotonic()
for _ in range(ITERS):
    a, b = 0, 1
    for _ in range(30): a, b = b, a + b
fib_result = b
fib_time = time.monotonic() - t0

# Sum 1..1000
t0 = time.monotonic()
for _ in range(ITERS):
    s = sum(range(1, 1001))
sum_result = s
sum_time = time.monotonic() - t0

print(f"Python Results (100K iterations each):")
print(f"  Factorial(20) = {fact_result} | {fact_time*1000:.3f} ms total | {fact_time*1e9/ITERS:.0f} ns/iter")
print(f"  Fibonacci(30) = {fib_result} | {fib_time*1000:.3f} ms total | {fib_time*1e9/ITERS:.0f} ns/iter")
print(f"  Sum(1..1000)  = {sum_result} | {sum_time*1000:.3f} ms total | {sum_time*1e9/ITERS:.0f} ns/iter")
print(f"  Total: {(fact_time+fib_time+sum_time)*1000:.3f} ms")
print()
PY

# ── 4. FLUX Python VM ──
echo "=== 4. FLUX Python VM ==="
PYTHONPATH=/home/ubuntu/.openclaw/workspace/repos/flux-runtime/src python3 << 'PY'
import time
from flux.vm.interpreter import Interpreter
import struct

ITERS = 10000  # fewer iterations for Python VM

def make_factorial():
    return bytes([0x2B,0x03,0x14,0x00, 0x2B,0x04,0x01,0x00,
                  0x0A,0x04,0x03, 0x0F,0x03, 0x06,0x03,0xF7,0xFF, 0x80])

def make_fibonacci():
    return bytes([0x2B,0x00,0x00,0x00, 0x2B,0x01,0x01,0x00, 0x2B,0x02,0x1E,0x00,
                  0x01,0x03,0x01, 0x08,0x01,0x00, 0x01,0x00,0x03,
                  0x0F,0x02, 0x06,0x02,0xF7,0xFF, 0x80])

def make_sum():
    return bytes([0x2B,0x00,0x00,0x00, 0x2B,0x01,0xE8,0x03,
                  0x08,0x00,0x01, 0x0F,0x01, 0x06,0x01,0xF7,0xFF, 0x80])

# Factorial
fact_bc = make_factorial()
t0 = time.monotonic()
for _ in range(ITERS):
    vm = Interpreter(fact_bc, memory_size=4096)
    vm.execute()
fact_time = time.monotonic() - t0
vm = Interpreter(fact_bc, memory_size=4096); vm.execute()
fact_result = vm.regs.read_gp(4)

# Fibonacci
fib_bc = make_fibonacci()
t0 = time.monotonic()
for _ in range(ITERS):
    vm = Interpreter(fib_bc, memory_size=4096)
    vm.execute()
fib_time = time.monotonic() - t0
vm = Interpreter(fib_bc, memory_size=4096); vm.execute()
fib_result = vm.regs.read_gp(1)

# Sum
sum_bc = make_sum()
t0 = time.monotonic()
for _ in range(ITERS):
    vm = Interpreter(sum_bc, memory_size=4096)
    vm.execute()
sum_time = time.monotonic() - t0
vm = Interpreter(sum_bc, memory_size=4096); vm.execute()
sum_result = vm.regs.read_gp(0)

print(f"FLUX Python VM Results (10K iterations each):")
print(f"  Factorial(20) = {fact_result} | {fact_time*1000:.3f} ms total | {fact_time*1e9/ITERS:.0f} ns/iter")
print(f"  Fibonacci(30) = {fib_result} | {fib_time*1000:.3f} ms total | {fib_time*1e9/ITERS:.0f} ns/iter")
print(f"  Sum(1..1000)  = {sum_result} | {sum_time*1000:.3f} ms total | {sum_time*1e9/ITERS:.0f} ns/iter")
print(f"  Total: {(fact_time+fib_time+sum_time)*1000:.3f} ms")
print(f"  Note: 10K iterations (Python VM is slower)")
print()
PY

# ── 5. Rust ──
echo "=== 5. Rust (flux-core) ==="
source "$HOME/.cargo/env"
cd /tmp/flux-core-rust

cat > benches/compare_bench.rs << 'EOF'
use std::time::Instant;

fn main() {
    let iters = 100_000;
    
    // Factorial 20 (native Rust)
    let start = Instant::now();
    let mut fact_result: i64 = 0;
    for _ in 0..iters {
        let mut r: i64 = 1;
        for n in 2..=20 { r *= n as i64; }
        fact_result = r;
    }
    let fact_time = start.elapsed();
    
    // Fibonacci 30
    let start = Instant::now();
    let mut fib_result: i64 = 0;
    for _ in 0..iters {
        let (mut a, mut b): (i64, i64) = (0, 1);
        for _ in 0..30 { let t = b; b = a + b; a = t; }
        fib_result = b;
    }
    let fib_time = start.elapsed();
    
    // Sum 1..1000
    let start = Instant::now();
    let mut sum_result: i64 = 0;
    for _ in 0..iters {
        let mut s: i64 = 0;
        for n in 1..=1000 { s += n; }
        sum_result = s;
    }
    let sum_time = start.elapsed();
    
    let total = fact_time + fib_time + sum_time;
    println!("Native Rust Results (100K iterations each):");
    println!("  Factorial(20) = {} | {:.3} ms | {:.1} ns/iter",
        fact_result, fact_time.as_secs_f64()*1000.0, fact_time.as_nanos() as f64 / iters as f64);
    println!("  Fibonacci(30) = {} | {:.3} ms | {:.1} ns/iter",
        fib_result, fib_time.as_secs_f64()*1000.0, fib_time.as_nanos() as f64 / iters as f64);
    println!("  Sum(1..1000)  = {} | {:.3} ms | {:.1} ns/iter",
        sum_result, sum_time.as_secs_f64()*1000.0, sum_time.as_nanos() as f64 / iters as f64);
    println!("  Total: {:.3} ms", total.as_secs_f64()*1000.0);
    println!();
}
EOF
rustc -O -o /tmp/flux-benchmarks/bench_rust benches/compare_bench.rs 2>&1
/tmp/flux-benchmarks/bench_rust

# ── 6. Shell (bash) ──
echo "=== 6. Bash ==="
python3 << 'PY'
import time, subprocess

ITERS = 100  # Bash is slow, use fewer iterations

# Factorial
t0 = time.monotonic()
for _ in range(ITERS):
    result = subprocess.run(['bash', '-c', 'r=1; for n in $(seq 2 20); do r=$((r*n)); done; echo $r'],
                          capture_output=True, text=True)
fact_time = time.monotonic() - t0

# Sum
t0 = time.monotonic()
for _ in range(ITERS):
    result = subprocess.run(['bash', '-c', 's=0; for n in $(seq 1 1000); do s=$((s+n)); done; echo $s'],
                          capture_output=True, text=True)
sum_time = time.monotonic() - t0

print(f"Bash Results (100 iterations each):")
print(f"  Factorial(20) | {fact_time*1000:.3f} ms total | {fact_time*1e9/ITERS:.0f} ns/iter")
print(f"  Sum(1..1000)  | {sum_time*1000:.3f} ms total | {sum_time*1e9/ITERS:.0f} ns/iter")
print(f"  Note: 100 iterations (Bash is very slow)")
print()
PY

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "Benchmark complete. Results saved to $RESULTS"
