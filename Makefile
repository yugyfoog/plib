CFLAGS = -g -Wall -Wextra
ASFLAGS = -g

OBJS = linux.o stdlib.o stdio.o ctype.o string.o math.o error.o argv.o xfer.o


libp.a: $(OBJS)
	ar rcs libp.a $(OBJS)

testalloc: testalloc.o libp.a
	cc -g -o testalloc testalloc.o libp.a

testpio: testpio.o libp.a
	cc -g -o testpio testpio.o libp.a

install: libp.a
	cp libp.a /usr/local/lib/

write: write.o
	cc -g -o write write.o -lm

clean:
	rm -f *.o *~
