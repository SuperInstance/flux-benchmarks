#include <stdio.h>
#include <stdint.h>
#include <time.h>
int main(){
    struct timespec s,e;
    int I=100000;
    clock_gettime(CLOCK_MONOTONIC,&s);
    int64_t fr=0;for(int i=0;i<I;i++){int64_t r=1;for(int n=2;n<=20;n++)r*=n;fr=r;}
    clock_gettime(CLOCK_MONOTONIC,&e);
    double ft=(e.tv_sec-s.tv_sec)+(e.tv_nsec-s.tv_nsec)/1e9;
    
    clock_gettime(CLOCK_MONOTONIC,&s);
    int64_t br=0;for(int i=0;i<I;i++){int64_t a=0,b=1;for(int n=0;n<30;n++){int64_t t=b;b=a+b;a=t;}br=b;}
    clock_gettime(CLOCK_MONOTONIC,&e);
    double bt=(e.tv_sec-s.tv_sec)+(e.tv_nsec-s.tv_nsec)/1e9;
    
    clock_gettime(CLOCK_MONOTONIC,&s);
    int64_t sr=0;for(int i=0;i<I;i++){int64_t v=0;for(int n=1;n<=1000;n++)v+=n;sr=v;}
    clock_gettime(CLOCK_MONOTONIC,&e);
    double st=(e.tv_sec-s.tv_sec)+(e.tv_nsec-s.tv_nsec)/1e9;
    
    printf("Native C (100K iters):\n");
    printf("  Factorial(20): %ld | %.3f ms | %.1f ns/iter\n",fr,ft*1000,ft*1e9/I);
    printf("  Fibonacci(30): %ld | %.3f ms | %.1f ns/iter\n",br,bt*1000,bt*1e9/I);
    printf("  Sum(1..1000):  %ld | %.3f ms | %.1f ns/iter\n",sr,st*1000,st*1e9/I);
    printf("  Total: %.3f ms\n\n",(ft+bt+st)*1000);
}
