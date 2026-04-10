#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

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
    struct timespec start,end;
    int ITERS=100000;
    
    uint8_t fact[]={0x2B,0x03,0x14,0x00,0x2B,0x04,0x01,0x00,0x0A,0x04,0x03,0x0F,0x03,0x06,0x03,0xF7,0xFF,0x80};
    uint8_t fib[]={0x2B,0x00,0x00,0x00,0x2B,0x01,0x01,0x00,0x2B,0x02,0x1E,0x00,0x01,0x03,0x01,0x08,0x01,0x00,0x01,0x00,0x03,0x0F,0x02,0x06,0x02,0xF7,0xFF,0x80};
    uint8_t sum[]={0x2B,0x00,0x00,0x00,0x2B,0x01,0xE8,0x03,0x08,0x00,0x01,0x0F,0x01,0x06,0x01,0xF7,0xFF,0x80};
    
    /* Factorial */
    clock_gettime(CLOCK_MONOTONIC,&start);
    for(int i=0;i<ITERS;i++){FVM v;memset(&v,0,sizeof(v));flux_run(&v,fact,sizeof(fact));}
    clock_gettime(CLOCK_MONOTONIC,&end);
    double ft=(end.tv_sec-start.tv_sec)+(end.tv_nsec-start.tv_nsec)/1e9;
    
    /* Fibonacci */
    clock_gettime(CLOCK_MONOTONIC,&start);
    for(int i=0;i<ITERS;i++){FVM v;memset(&v,0,sizeof(v));flux_run(&v,fib,sizeof(fib));}
    clock_gettime(CLOCK_MONOTONIC,&end);
    double bt=(end.tv_sec-start.tv_sec)+(end.tv_nsec-start.tv_nsec)/1e9;
    
    /* Sum */
    clock_gettime(CLOCK_MONOTONIC,&start);
    for(int i=0;i<ITERS;i++){FVM v;memset(&v,0,sizeof(v));flux_run(&v,sum,sizeof(sum));}
    clock_gettime(CLOCK_MONOTONIC,&end);
    double st=(end.tv_sec-start.tv_sec)+(end.tv_nsec-start.tv_nsec)/1e9;
    
    FVM vf,vb,vs;
    memset(&vf,0,sizeof(vf));flux_run(&vf,fact,sizeof(fact));
    memset(&vb,0,sizeof(vb));flux_run(&vb,fib,sizeof(fib));
    memset(&vs,0,sizeof(vs));flux_run(&vs,sum,sizeof(sum));
    
    printf("FLUX C VM (100K iters):\n");
    printf("  Factorial(20): R4=%d | %.3f ms | %.0f ns/iter\n",vf.gp[4],ft*1000,ft*1e9/ITERS);
    printf("  Fibonacci(30): R1=%d | %.3f ms | %.0f ns/iter\n",vb.gp[1],bt*1000,bt*1e9/ITERS);
    printf("  Sum(1..1000):  R0=%d | %.3f ms | %.0f ns/iter\n",vs.gp[0],st*1000,st*1e9/ITERS);
    printf("  Total: %.3f ms\n\n",(ft+bt+st)*1000);
    return 0;
}
