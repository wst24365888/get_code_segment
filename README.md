# get_code_segment

## About

Term project of Linux OS, 2021 fall @ NCU CSIE.

## Target

Add a system call to return some memory info of a process's code segment.

## Note

## 1. asmlinkage 作用

- \_\_attribute\_\_是C語言的gcc擴展，用來設置函數屬性、變數屬性和類型屬性等，可以幫助編譯器執行優化。

- <https://gcc.gnu.org/onlinedocs/gcc/x86-Function-Attributes.html>

    > regparm(n)
    >
    > On x86-32 targets, the regparm attribute causes the compiler to pass arguments number one to n if they are of integral type in registers EAX, EDX, and ECX instead of on the stack. Functions that take a variable number of arguments continue to be passed all of their arguments on the stack.
    >
    > Beware that on some ELF systems this attribute is unsuitable for global functions in shared libraries with lazy binding (which is the default). Lazy binding sends the first call via resolving code in the loader, which might assume EAX, EDX and ECX can be clobbered, as per the standard calling conventions. Solaris 8 is affected by this. Systems with the GNU C Library version 2.1 or higher and FreeBSD are believed to be safe since the loaders there save EAX, EDX and ECX. (Lazy binding can be disabled with the linker or the loader if desired, to avoid the problem.)

  - \_\_attribute\_\_((regparm(n))), n介於1~3：告訴gcc編譯器這個函數可以通過register傳遞多達n個的參數，這3個register依次為EAX、EDX 和 ECX。更多的參數才通過stack傳遞。這樣可以減少一些對於stack操作，因此調用比較快。

- <https://elixir.bootlin.com/linux/v5.14.9/source/arch/x86/include/asm/linkage.h>

    ```c
    #define asmlinkage CPP_ASMLINKAGE __attribute__((regparm(0))) 
    ```

  - \_\_attribute\_\_((regparm(0)))：告訴gcc編譯器該函數不需要通過任何register來傳遞參數，參數只通過stack來傳遞。

- <https://kernelnewbies.org/FAQ/asmlinkage>

    > Recall our earlier assertion that system_call consumes its first argument, the system call number, and allows up to four more arguments that are passed along to the real system call. system_call achieves this feat simply by leaving its other arguments (which were passed to it in registers) on the stack. All system calls are marked with the asmlinkage tag, so they all look to the stack for arguments.

## 2. sys_前綴 & SYSCALL_DEFINEx 擴展

- SYSCALL_DEFINEx由來：早期64位元Linux存在CVE-2009-2009的漏洞，簡單說就是32位元參數存放在64位元的register無法做符號擴展，因此有心人士修改符號擴展可能導致產生一個非法內存地址，從而導致系統crash或者提升權限。為了修這個問題，本來把register高位清零即可，但需要大量修改，為了做減少cost，將調用參數統一使用`long`型別來接收，再強轉為相應參數。

- <https://elixir.bootlin.com/linux/v5.14.9/source/include/linux/syscalls.h#L208>

  - 擴展

    ```c=
    #ifndef SYSCALL_DEFINE0
    #define SYSCALL_DEFINE0(sname)     \
        SYSCALL_METADATA(_##sname, 0);    \
        asmlinkage long sys_##sname(void);   \
        ALLOW_ERROR_INJECTION(sys_##sname, ERRNO);  \
        asmlinkage long sys_##sname(void)
    #endif /* SYSCALL_DEFINE0 */

    #define SYSCALL_DEFINE1(name, ...) SYSCALL_DEFINEx(1, _##name, __VA_ARGS__)
    #define SYSCALL_DEFINE2(name, ...) SYSCALL_DEFINEx(2, _##name, __VA_ARGS__)
    #define SYSCALL_DEFINE3(name, ...) SYSCALL_DEFINEx(3, _##name, __VA_ARGS__)
    #define SYSCALL_DEFINE4(name, ...) SYSCALL_DEFINEx(4, _##name, __VA_ARGS__)
    #define SYSCALL_DEFINE5(name, ...) SYSCALL_DEFINEx(5, _##name, __VA_ARGS__)
    #define SYSCALL_DEFINE6(name, ...) SYSCALL_DEFINEx(6, _##name, __VA_ARGS__)
    ```

  - 其中`SYSCALL_DEFINEx`的x為參數個數，`name`為syscall名字，`__VA_ARGS__`為參數

  - 進一步擴展

    ```c=
    /*
     * The asmlinkage stub is aliased to a function named __se_sys_*() which
     * sign-extends 32-bit ints to longs whenever needed. The actual work is
     * done within __do_sys_*().
     */
    #ifndef __SYSCALL_DEFINEx
    #define __SYSCALL_DEFINEx(x, name, ...)     \
        __diag_push();       \
        __diag_ignore(GCC, 8, "-Wattribute-alias",   \
                  "Type aliasing is used to sanitize syscall arguments");\
        asmlinkage long sys##name(__MAP(x,__SC_DECL,__VA_ARGS__)) \
            __attribute__((alias(__stringify(__se_sys##name)))); \
        ALLOW_ERROR_INJECTION(sys##name, ERRNO);   \
        static inline long __do_sys##name(__MAP(x,__SC_DECL,__VA_ARGS__));\
        asmlinkage long __se_sys##name(__MAP(x,__SC_LONG,__VA_ARGS__)); \
        asmlinkage long __se_sys##name(__MAP(x,__SC_LONG,__VA_ARGS__)) \
        {        \
            long ret = __do_sys##name(__MAP(x,__SC_CAST,__VA_ARGS__));\
            __MAP(x,__SC_TEST,__VA_ARGS__);    \
            __PROTECT(x, ret,__MAP(x,__SC_ARGS,__VA_ARGS__)); \
            return ret;      \
        }        \
        __diag_pop();       \
        static inline long __do_sys##name(__MAP(x,__SC_DECL,__VA_ARGS__))
    #endif /* __SYSCALL_DEFINEx */
    ```

  - 可以看到`sys_name`調用`__se_sys_name`，`__se_sys_name`再調用`__do_sys_name`，所以我們要找到調用sys_name的地方 --> `arch/x86/entry/syscalls/syscall_64.tbl`

    - sys_前綴：推測應是為了配合 SYSCALL_DEFINEx 擴展

  - 實際用`syscall_64.tbl`生成的檔案會在這兩個地方找到

    - <https://elixir.bootlin.com/linux/v5.14.9/source/arch/x86/include/generated/asm/syscalls_64.h>

        ```c
        // arch/x86/include/generated/asm/syscalls_64.h

        __SYSCALL(xxx, sys_name)
        ```

    - <https://elixir.bootlin.com/linux/v5.14.9/source/arch/x86/include/generated/uapi/asm/unistd_64.h>

        ```c
        // arch/x86/include/generated/uapi/asm/unistd_64.h

        #define __NR_name xxx       
        ```

  - 引入`syscalls_64.h`的檔案生成`sys_call_table`

    - <https://elixir.bootlin.com/linux/v5.14.9/source/arch/x86/entry/syscall_64.c>

        ```c
        // arch/x86/entry/syscall_64.c

        #define __SYSCALL(nr, sym) __x64_##sym,

        asmlinkage const sys_call_ptr_t sys_call_table[] = {
        #include <asm/syscalls_64.h>
        };
        ```

  - 使用編號搭配`sys_call_table`，並呼叫的地方

    - <https://elixir.bootlin.com/linux/v5.14.9/source/arch/x86/entry/common.c>

        ```c
        // arch/x86/entry/common.c

        __visible noinstr void do_syscall_64(struct pt_regs *regs, int nr)
        {
            add_random_kstack_offset();
            nr = syscall_enter_from_user_mode(regs, nr);

            instrumentation_begin();

            if (!do_syscall_x64(regs, nr) && !do_syscall_x32(regs, nr) && nr != -1) {
                /* Invalid system call, but still a system call. */
                regs->ax = __x64_sys_ni_syscall(regs);
            }

            instrumentation_end();
            syscall_exit_to_user_mode(regs);
        }

        static __always_inline bool do_syscall_x64(struct pt_regs *regs, int nr)
        {
            /*
             * Convert negative numbers to very high and thus out of range
             * numbers for comparisons.
             */
            unsigned int unr = nr;

            if (likely(unr < NR_syscalls)) {
                unr = array_index_nospec(unr, NR_syscalls);
                regs->ax = sys_call_table[unr](regs);
                return true;
            }
            return false;
        }
        ```

  - 呼叫`do_syscall_64`的地方

    - <https://elixir.bootlin.com/linux/v5.14.9/source/arch/x86/entry/entry_64.S>

        ```c
        // arch/x86/entry/entry_64.S

        SYM_CODE_START(entry_SYSCALL_64)
            ...
            call do_syscall_64  /* returns with IRQs disabled */
            ...
        ```

  - 用到該組合語言段落的地方，也就是呼叫syscall的時候

    - <https://elixir.bootlin.com/linux/v5.14.9/source/arch/x86/kernel/cpu/common.c>

        ```c
        // arch/x86/kernel/cpu/common.c

        void syscall_init(void)
        {
                ...
                wrmsrl(MSR_LSTAR, (unsigned long)entry_SYSCALL_64);
                ...
        }
        ```

## 3. mm_struct vm_area_struct

- 兩個都是用來描述(? process address space
- mm_struct 是用來描述 process的address space
  - 用black-red tree 和 link-list來管理
- vm_area_struct是用來指定process實際的大小空間
  - rb_node連接到mm_struct的red-black tree
  - vm_prev,vm_next是link到mm_struct的link-list裡

## 4. 有關於vmmap印出來跟C file dump出來的end address 不一樣的那一回事

- 感覺是mm_struct分配了4000-42a5的空間 但是vm_area_struct實際上只用了4000-4200的空間 所以00-a5應該是空下來的space
