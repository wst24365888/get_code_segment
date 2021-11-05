#include <syscall.h>
#include <sys/types.h>
#include <stdio.h>
#include <unistd.h>
#include <time.h>

#define __x64_sys_get_code_segment 448

struct code_segment
{
    unsigned long start_code;
    unsigned long end_code;
};

int main()
{
    struct code_segment my_code_segment;

    int a = syscall(__x64_sys_get_code_segment, getpid(), (void *)&my_code_segment);

    printf("Start: %lx\nEnd: %lx\n", my_code_segment.start_code, my_code_segment.end_code);

    return 0;
}