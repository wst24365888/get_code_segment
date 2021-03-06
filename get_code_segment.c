#include <linux/kernel.h>
#include <linux/string.h>
#include <linux/uaccess.h>
#include <linux/sched.h>
#include <linux/syscalls.h>
#include <asm/errno.h>

struct code_segment
{
    unsigned long start_code;
    unsigned long end_code;
};

SYSCALL_DEFINE2(get_code_segment, pid_t, current_pid, void *__user, user_code_segment)
{
    struct task_struct *task;
    struct code_segment code_segment;
    unsigned long start_code, end_code;

    task = find_task_by_vpid(current_pid);
    if (!task)
    {
        return -EINVAL;
    }

    start_code = (unsigned long)task->mm->start_code;
    end_code = (unsigned long)task->mm->end_code;

    code_segment.start_code = start_code;
    code_segment.end_code = end_code;

    if (copy_to_user(user_code_segment, &code_segment, sizeof(code_segment)))
    {
        return -EFAULT;
    }

    return 0;
}