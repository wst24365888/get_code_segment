add_syscall:
	./setup.sh

test:
	gcc -o test.o test.c && ./test.o