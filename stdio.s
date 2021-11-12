	# Pascal standard library
	#    stdio.s -- standard input/output routines
	#       NOTE: while many of these routines resemble
	#             clib routines, they are signifantly
	#             different.

	# constants needed by open
	
	.equ	O_RDONLY,0
	.equ	O_WRONLY,1
	.equ	O_CREAT,64
	.equ	O_TRUNC,512

	
	.equ	NFILES,20     	# number of files that can be open
	.equ	BUFF_SIZE,512	# size of buffer for text files
	
	# struct file_type {
	#     char *buff
	#     long count
	#     char *bptr
	#     int fd
	#     unsigned int flags
	# }
	
	.equ	BUFF,0
	.equ	COUNT,8   # number of characters left in buffer (only used for text/input)
	.equ	BPTR,16
	.equ	FD,24
	.equ	FLAGS,28

	.equ	FILE_TYPE_SIZE,32

	# file flags

	# flags == 0 => file not open
	
	.equ	READ_MODE,1
	.equ	WRITE_MODE,2
	.equ	BINARY_FILE,4
	.equ	TEXT_FILE,8

	.data
	.align	8
	.globl	files
	.globl	input
	.globl	output
	.globl	error
files:
input:	.quad	inbuf,0,inbuf
	.long	0,READ_MODE|TEXT_FILE
output:	.quad	outbuf,0,outbuf
	.long	1,WRITE_MODE|TEXT_FILE
error:	.quad	errbuf,0,errbuf
	.long	2,WRITE_MODE|TEXT_FILE
more_files:
	.zero	(NFILES-3)*FILE_TYPE_SIZE
last_file:
	.bss
	.align	8
inbuf:	.zero	BUFF_SIZE
outbuf:	.zero	BUFF_SIZE
errbuf:	.zero	BUFF_SIZE
	
	.text
	
	##################################################################
	#
	# p_close(FILE *stream)
	#    close a file
	#
	
	.align	8
	.globl	p_close
p_close:
	push	%rbx
	mov	%rdi,%rbx
	call	p_fflush
	xor	%eax,%eax
	mov	%eax,FLAGS(%rbx)
	mov	FD(%rbx),%rdi
	call	sys_close
	pop	%rbx
	ret

	##################################################################
	#
	# named_reset_text(FILE **stream, char *name, long length)
	#    open a text file for reading.
	#
	
	.align	8
	.globl	named_reset_text
named_reset_text:
	push	%rbx
	push	%r12
	push	%r13
	mov	%rdi,%rbx		# %rbx = STREAM
	mov	%rsi,%r12		# %r12 = NAME
	mov	%rdx,%r13		# %e13 = LENGTH (length of NAME)
	call	find_free_file		# %r12 = free file slot
	test	%rax,%rax		# if (not free slots)
	js	1f			#     goto fail
	mov	%rax,(%rbx)		# save free slot to (STREAM)
	mov	%rax,%rbx		# %rbx is now FILE
	mov	$BUFF_SIZE,%rdi		# %rax = malloc(BUFF_SIZE)
	call	p_malloc
	test	%rax,%rax		# if (no free memory)
	jz	1f			#     goto fail
	mov	%rax,BUFF(%rbx)		# save buffer to FILE.BUFF
	mov	%rax,BPTR(%rbx)		#     and FILE.BPTR
	xor	%rax,%rax		# FILE.COUNT = 0
	mov	%rax,COUNT(%rbx)
	movl	$READ_MODE|TEXT_FILE,FLAGS(%rbx)	# FILE.FLAGS = read/text mode
	mov	%r12,%rdi		# %rax = pascal_to_c_string(NAME, LENGTH)
	mov	%r13,%rsi
	call	pascal_to_c_string
	mov	%rax,%rdi		# %rax = truncate_at_blank(%rax)
	call	truncate_at_blank
	mov	%rax,%rdi		# %rax = open(%rax,O_RDONLY)
	xor	%rsi,%rsi		#    (O_RDONLY = 0)
	call	p_open
	test	%eax,%eax		# if (open failed)
	js	1f			#     goto fail
	mov	%eax,FD(%rbx)		# FILE.FD = %eax (file handle)
	pop	%r13
	pop	%r12
	pop	%rbx
	ret
1:	lea	reset_fail(%rip),%rdi
	call	pascal_error

	.align	8
reset_fail:
	.string	"reset fail"

	##################################################################
	#
	# named_rewrite_text(FILE *stream, char *name, long length)
	#    create a text file for writing.
	#
	
	.align	8
	.globl	named_rewrite_text
named_rewrite_text:
	# FILE
	# NAME
	# LENGTH
	push	%rbx
	push	%r12
	push	%r13
	mov	%rdi,%rbx
	mov	%rsi,%r12
	mov	%rdx,%r13
	call	find_free_file
	test	%rax,%rax
	js	1f
	mov	%rax,(%rbx)
	mov	%rax,%rbx
	mov	$BUFF_SIZE,%rdi
	call	p_malloc
	test	%rax,%rax
	jz	1f
	mov	%rax,BUFF(%rbx)
	mov	%rax,BPTR(%rbx)
	xor	%rax,%rax
	mov	%rax,COUNT(%rbx)
	movl	$WRITE_MODE|TEXT_FILE,FLAGS(%rbx)
	mov	%r12,%rdi
	mov	%r13,%rsi
	call	pascal_to_c_string
	mov	%rax,%rdi
	call	truncate_at_blank
	mov	%rax,%rdi
	mov	$O_CREAT|O_WRONLY|O_TRUNC,%rsi
	mov	$0644,%rdx
	call	p_open
	test	%eax,%eax
	js	1f
	mov	%eax,FD(%rbx)
	pop	%r13
	pop	%r12
	pop	%rbx
	ret
1:	lea	rewrite_fail(%rip),%rdi
	call	pascal_error

	.align	8
rewrite_fail:
	.string	"rewrite fail"

	##################################################################
	#
	# FILE *find_free_file(void)
	#   -- find a free file slot
	#
	
	.align	8
find_free_file:
	lea	last_file(%rip),%rdi
	lea	more_files(%rip),%rax		# don't bother checking input, output and error
1:	mov	FLAGS(%rax),%esi
	test	%esi,%esi
	jz	2f
	add	$FILE_TYPE_SIZE,%rax
	cmp	%rax,%rdi
	jne	1b
	mov	$-1,%rax
2:	ret

	##################################################################
	#
	# char *pascal_to_c_string(char *PSTR, long SIZE)
	#    convert pascal to c-string
	#
	
	.align	8
pascal_to_c_string:
	push	%rbx
	push	%r12
	mov	%rdi,%rbx
	mov	%rsi,%r12
	mov	ptocptr(%rip),%rax
	mov	ptocsize(%rip),%rdx
	dec	%rdx
	cmp	%rdx,%r12
	jl	1f
	mov	%rax,%rdi
	call	p_free
	lea	1(%r12),%rdi
	mov	%rdi,ptocsize(%rip)
	call	p_malloc
	test	%rax,%rax
	jz	3f
	mov	%rax,ptocptr(%rip)
1:	mov	%rax,%rdx
	lea	(%rdx,%r12),%rdx
	lea	(%rbx,%r12),%rbx
	neg	%r12
2:	mov	(%rbx,%r12),%cl
	mov	%cl,(%rdx,%r12)
	inc	%r12
	jnz	2b
	mov	%r12,(%rdx)		# %r12 is zero
	pop	%r12
	pop	%rbx
	ret
3:	lea	pascal_to_c_string_fail(%rip),%rdi
	call	pascal_error
	
	.align	8
pascal_to_c_string_fail:
	.string	"pascal_to_c_string_fail"
	
	.bss
	.align	8
ptocptr:	.zero	8
ptocsize:	.zero	8
	
	.text
	.align	8
	# char *truncate_at_blank(char *STR)
	#    place a '\0' at the first non graphic character
truncate_at_blank:
	mov	%rdi,%rax	# save for return value
1:	mov	(%rdi),%cl
	inc	%rdi
	sub	$33,%cl
	cmp	$128-33,%cl
	jb	1b
	xor	%cl,%cl
	mov	%cl,-1(%rdi)
	ret

	# void write_boolean(FILE *STREAM, boolean T, long WIDTH)
	
	.align	8
	.globl	write_boolean
write_boolean:
	push	%rbx
	push	%r12
	mov	%rdi,%rbx
	mov	%rsi,%r12
	cmp	$1,%r12
	sbb	$4,%rdx
	jb	1f
	mov	%rdx,%rdi
	mov	%rbx,%rsi
	call	spaces
1:	mov	%rbx,%rsi
	lea	true_string(%rip),%rdi
	lea	false_string(%rip),%rax
	test	%r12,%r12
	cmovz	%rax,%rdi
	call	fputs
	pop	%r12
	pop	%rbx
	ret

	.align	8
false_string:
	.string	"false"
	.align	8
true_string:
	.string "true"
	
	# void write_character(FILE *stream, long c, long width)
	#     write a character to test stream

	.align	8
	.globl	write_character
write_character:
	push	%rbx
	push	%r12
	mov	%rdi,%rbx
	mov	%rsi,%r12
	mov	%rdx,%rdi
	sub	$1,%rdi
	jz	1f
	mov	%rbx,%rsi
	call	spaces
1:	mov	%r12,%rdi
	mov	%rbx,%rsi
	call	fputc
	pop	%r12
	pop	%rbx
	ret

	# void write_integer(FILE *stream, long x, long width)
	#     write in integer to text stream with a field width of width
	.align	8
	.globl	write_integer
write_integer:
	push	%rbx
	push	%r12
	push	%r13
	mov	%rdi,%rbx
	mov	%rdx,%r12
	mov	%rsi,%rdi
	call	convert_integer_to_ascii
	mov	%rax,%r13
	mov	%rax,%rdi
	call	p_strlen
	sub	%rax,%r12
	mov	%r12,%rdi
	mov	%rbx,%rsi
	call	spaces
	mov	%rbx,%rsi
	mov	%r13,%rdi
	call	fputs
	pop	%r13
	pop	%r12
	pop	%rbx
	ret

	# void p_write_real_float(FILE *stream, double e, int width)
	#      write a real to stream
	#      scientific notation
	
	.align	8
	.globl	p_write_real_float
p_write_real_float:
	push	%rbx
	push	%r12
	push	%r13
	push	%r14
	push	%r15
	sub	$8,%rsp
	movsd	%xmm0,(%rsp)
	
	mov	%rdi,%rbx
	
	# add checks for NAN's and INFINITIES here!

	# actual_width = min(9, width) -- actual_width of 9 will give us 1 decimal place

	mov	$9,%r12
	cmp	%rsi,%r12
	cmovl	%rsi,%r12

	# decimal_places = actual_width - 8
	#     8 = 1(initial sign) + 1(initial digits) + 1(decimal point) + 1('e' for exponent)
	#         + 1(exponent sign) + 3(exponent)

	sub	$8,%r12

	# if e < 0
	#    e = abs(e)
	#    fputc('-', stream)
	# else
	#    fputc(' ', stream)

	mov	$' ',%rdi
	xorpd	%xmm1,%xmm1
	comisd	(%rsp),%xmm1
	jbe	1f
	subsd	(%rsp),%xmm1
	movsd	%xmm1,(%rsp)
	
	mov	$'-',%rdi
1:	
	mov	%rbx,%rsi
	call	fputc

	#  if e == 0.0
	#       goto print zero
	
	movsd	(%rsp),%xmm0
	comisd	zero(%rip),%xmm0
	je	5f
	
	#  exponent = floor(log10(e))
	

	call	log10
	call	floor
	vcvttsd2si %xmm0,%r15

	# E /= pow(10.0,exponent)
	
	mov	%r15,%rdi
	movsd	ten(%rip),%xmm0
	call	powi
	movsd	(%rsp),%xmm1
	divsd	%xmm0,%xmm1
	movsd	%xmm1,(%rsp)

	# print first digit
	
	lea	(%rsp),%rdi
	mov	%rbx,%rsi
	call	put_left_char

	# print decimal point

	mov	$'.',%rdi
	mov	%rbx,%rsi
	call	fputc

2:	# print remaining digits

	lea	(%rsp),%rdi
	mov	%rbx,%rsi
	call	put_left_char
	dec	%r12
	jnz	2b

	# print 'e'

	mov	$'e',%rdi
	mov	%rbx,%rsi
	call	fputc

	# print exponent sign
	
	mov	$'+',%rdi
	test	%r15,%r15
	jns	3f
	neg	%r15
	mov	$'-',%rdi
3:	
	mov	%rbx,%rsi
	call	fputc

	# print exponent digits
	
	mov	%r15,%rax
	mov	$10,%r15

	xor	%rdx,%rdx
	div	%r15
	add	$'0',%rdx
	mov	%rdx,%r14
	
	xor	%rdx,%rdx
	div	%r15
	add	$'0',%rdx
	mov	%rdx,%r13
	
	xor	%rdx,%rdx
	div	%r15
	add	$'0',%rdx
	mov	%rdx,%rdi

	mov	%rbx,%rsi
	call	fputc

	mov	%r13,%rdi
	mov	%rbx,%rsi
	call	fputc

	mov	%r14,%rdi
	mov	%rbx,%rsi
	call	fputc
	
4:	add	$8,%rsp
	pop	%r15
	pop	%r14
	pop	%r13
	pop	%r12
	pop	%rbx
	ret

5:	# print zero
	# we've already printed the sign.

	# print "0."

	lea	zero1(%rip),%rdi
	mov	%rbx,%rsi
	call	fputs

	# print DIGITS '0's

6:	mov	$'0',%rdi
	mov	%rbx,%rsi
	call	fputc
	dec	%r12
	jnz	6b

	# print "e+000"

	lea	zero2(%rip),%rdi
	mov	%rbx,%rsi
	call	fputs
	jmp	4b

	.data
	.align	8
zero:	.quad	0
zero1:	.string	"0."
zero2:	.string "e+000"
	.text
	##################################################################
	#
	# void put_left_char(double *x, FILE *stream)
	#   -- x is a number: 0 <= x < 10
	#          print the leading digits of x
	#          multiply x times 10 and save

	.align	8
put_left_char:
	vmovsd	(%rdi),%xmm0
	vcvttsd2si	%xmm0,%rax
	vcvtsi2sd	%rax,%xmm1,%xmm1
	vsubsd	%xmm1,%xmm0,%xmm0
	vmulsd	ten(%rip),%xmm0,%xmm0
	vmovsd	%xmm0,(%rdi)
	lea	'0'(%rax),%rdi
	call	fputc
	ret
	
	.align	8
half:	.quad	0x3fe0000000000000
ten:	.quad	0x4024000000000000

	# void write_string(FILE *stream, char *x, long size, long width)
	#      write a (Pascal) string to stream
	.align	8
	.globl	write_string
write_string:	
	push	%rbx
	push	%r12
	push	%r13
	mov	%rdi,%rbx
	mov	%rsi,%r12
	mov	%rdx,%r13
	mov	%rcx,%rdi
	sub	%r13,%rdi
	jle	1f
	mov	%rbx,%rsi
	call	spaces
	xor	%rdi,%rdi
1:	mov	(%r12),%dil
	inc	%r12
	mov	%rbx,%rsi
	call	fputc
	dec	%r13
	jnz	1b
	pop	%r13
	pop	%r12
	pop	%rbx
	ret
	
	# void writeln(FILE *stream)
	#     put a newline to stream

	.globl	writeln
writeln:
	mov	%rdi,%rsi
	mov	$'\n',%dil
	call	fputc
	ret

	
	# int fputs(const char *str, FILE *stream)
	#      put string src to stream
	.align	8
	.globl	fputs
fputs:
	push	%rbx
	push	%r12
	mov	%rdi,%rbx
	mov	%rsi,%r12
1:	xor	%edi,%edi
	mov	(%rbx),%dil
	inc	%rbx
	test	%dil,%dil
	jz	2f
	mov	%r12,%rsi
	call	fputc
	jmp	1b
2:	pop	%r12
	pop	%rbx
	ret
	
	# int p_fputc(int c, FILE *stream)
	#     put c on to stream
	.align	8
	.globl	fputc
fputc:	
	mov	BPTR(%rsi),%rax
	mov	%dil,(%rax)
	inc	%rax
	mov	%rax,BPTR(%rsi)
	cmp	$'\n',%dil
	je	1f              # newline -- do a flush
	sub	BUFF(%rsi),%rax
	cmp	$BUFF_SIZE,%rax
	jl	2f	        # buffer not full, no flush
1:	mov	%rsi,%rdi
	call	p_fflush
2:	ret

	# void read_character(FILE *stream, char *C)
	#    read a character from input
	
	.align	8
	.globl	read_character
read_character:	
	push	%rbx
	mov	%rsi,%rbx
	call	fgetc
	mov	%al,(%rbx)
	pop	%rbx
	ret

        ################################################################
        #
        # void read_integer(FILE *stream, int *xp)
        #     read an integer from text file and save *x
        #
        # %rbx STREAM
        # %r12 C
        # %r13 X
        # %r14 SIGN
        # %r15 XP
        
        .align  8
        .globl  read_integer
read_integer:
        push    %rbx
        push    %r12
        push    %r13
        push    %r14
        push    %r15
        
        mov     %rdi,%rbx
        mov     %rsi,%r15

        mov     %rbx,%rdi
        call    whitespace

        mov     %rbx,%rdi
        call    fgetc
        mov     %rax,%r12

        mov     $1,%r14
        cmp     $'+',%r12
        jne     2f
1:      mov     %rbx,%rdi
        call    fgetc
        mov     %rax,%r12
        jmp     3f
2:      cmp     $'-',%r12
        jne     3f
        sub     $2,%r14
        jmp     1b
3:
        xor     %r13,%r13
4:
        mov     %r12,%rax
        sub     $'0',%rax
        cmp     $9,%rax
        ja      5f

        lea     (%r13,%r13,4),%r13
        shl     $1,%r13
        add     %rax,%r13

        mov     %rbx,%rdi
        call    fgetc
        mov     %rax,%r12
        jmp     4b
5:
        mov     %r12,%rdi
        mov     %rbx,%rsi
        call    ungetc

        mov     %r13,%rax
        neg     %r13
        test    %r14,%r14
        cmovs   %r13,%rax
        mov     %rax,(%r15)

        pop     %r15
        pop     %r14
        pop     %r13
        pop     %r12
        pop     %rbx
        ret

        
	################################################################
	#
	# void read_real(FILE *stream, double *x)
	#     read a real from text file and save *x
	#
	#		X       (save X on stack, not needed til end)
	# %rbx		STREAM  (move from %rdi
	# %r12		SIGN
	# %r13		C
	# %r14		DECIMALS
	# %r15		EXP
	# (%rsp)	BASE (float)
	# %xmm0 	TEMP (float)
	#

	.align	8
	.globl	read_real
read_real:
	push	%rbx
	push	%r12
	push	%r13
	push	%r14
	push	%r15
	
	push	%rsi	# save X
	mov	%rdi,%rbx

	sub	$8,%rsp
	
	# whitespace(stream)
	
	mov	%rbx,%rdi
	call	whitespace

	# c = fgetc(stream)
	
	mov	%rbx,%rdi
	call	fgetc
	mov	%rax,%r13

	# sign = 1
	# if c == '+'
	#    c = fgetc(stream)
	# else if c == '-'
	#    sign = -1
	#    c = fgetc(stream)

	mov	$1,%r12
	cmp	$'+',%r13
	jne	2f
1:	mov	%rbx,%rdi
	call	fgetc
	mov	%rax,%r13
	jmp	3f
2:	cmp	$'-',%r13
	jne	3f
	sub	$2,%r12
	jmp	1b
3:
	# base = 0
	# decimals = 0
	
	xor	%r14,%r14
	mov	%r14,(%rsp)

	
	# while (isdigit(c))
4:	
	mov	%r13,%rdi
	call	isdigit
	test	%rax,%rax
	jz	5f

	#     base = 10*base + c - '0'

	sub	$'0',%r13
	vcvtsi2sd %r13,%xmm0,%xmm0
	movsd	(%rsp),%xmm1
	mulsd	ten(%rip),%xmm1
	addsd	%xmm0,%xmm1
	movsd	%xmm1,(%rsp)

	#     c = fgetc(stream)

	mov	%rbx,%rdi
	call	fgetc
	mov	%rax,%r13
	jmp	4b
	
5:	# if (c == '.')

	cmp	$'.',%r13
	jne	7f

	#     c = fgetc(stream)

	mov	%rbx,%rdi
	call	fgetc
	mov	%rax,%r13
	
	#     while (isdigit(c))
6:	
	mov	%r13,%rdi
	call	isdigit
	test	%rax,%rax
	jz	7f

	#         base = 10*base + c - '0'

	sub	$'0',%r13
	vcvtsi2sd %r13,%xmm0,%xmm0
	movsd	(%rsp),%xmm1
	mulsd	ten(%rip),%xmm1
	addsd	%xmm0,%xmm1
	movsd	%xmm1,(%rsp)

	#         decimals++

	inc	%r14

	#         c = fgetc(stream)

	mov	%rbx,%rdi
	call	fgetc
	mov	%rax,%r13
	jmp	6b

7:	# exp = 0

	xor	%r15,%r15
	
	# if (c == 'e' || c == 'E')

	cmp	$'e',%r13
	je	8f
	cmp	$'E',%r13
	jne	10f
8:	
	#     c = fgetc(stream)

	mov	%rbx,%rdi
	call	fgetc
	mov	%rax,%r13

	# while (isdigit(c))
9:	
	mov	%r13,%rdi
	call	isdigit
	test	%rax,%rax
	jz	10f

	#     exp = 10*exp + c - '0'

	lea	(%r15,%r15,4),%r15
	shl	$1,%r15
	lea	-48(%r15, %r13),%r15

	#     c = fgetc(stream)

	mov	%rbx,%rdi
	call	fgetc
	mov	%rax,%r13
	jmp	9b

10:	# ungetc(C, STREAM)

	mov	%r13,%rdi
	mov	%rbx,%rsi
	call	ungetc

	#  return sign * base * 10^(exp - decimals)
	sub	%r14,%r15
	mov	%r15,%rdi
	movsd	ten(%rip),%xmm0
	call	powi
	mulsd	(%rsp),%xmm0
	vcvtsi2sd %r12,%xmm1,%xmm1
	mulsd	%xmm1,%xmm0

	add	$8,%rsp
	pop	%rax
	movsd	%xmm0,(%rax)
	pop	%r15
	pop	%r14
	pop	%r13
	pop	%r12
	pop	%rbx
	ret

	##################################################################
	#
	# void whitespace(FILE *stream)
	#    -- skip non-printiable characters on input steam
	#
	.align	8
whitespace:
	push	%rbx
	push	%r12
	mov	%rdi,%rbx

1:	# while (!isgraph(c = fgetc(stream)))

	mov	%rbx,%rdi
	call	fgetc
	mov	%rax,%r12
	mov	%rax,%rdi
	call	isgraph
	test	%rax,%rax
	jz	1b

	# ungetc(c, stream)

	mov	%r12,%rdi
	mov	%rbx,%rsi
	call	ungetc

	pop	%r12
	pop	%rbx
	ret
	
	##################################################################
	#
	# void readln(FILE *stream)
	#     skip input til next line
	#
	.align	8
	.globl	readln
readln:
	push	%rbx
	mov	%rdi,%rbx
1:
	mov	%rbx,%rdi	# first check for end of file
	call	p_eof
	test	%rax,%rax
	jnz	2f		# eof -- we're done

	mov	%rbx,%rdi	# check for newline character
	call	p_eoln
	test	%rax,%rax
	jnz	3f		# newline found (read next character without reading it)

	mov	%rbx,%rdi
	call	fgetc
	jmp	1b
3:
	# if COUNT(%rbx) > 0 then just increment BPTR(%rbx) and decrement COUNT(%rbx)
	#                    else set COUNT(%rbx) to zero so next pfgetc with input the next line
	cmpq	$0,COUNT(%rbx)
	jz	4f
	incq	BPTR(%rbx)
	decq	COUNT(%rbx)
	jmp	2f
4:	movq	$0,COUNT(%rbx)

2:	pop	%rbx
	ret

	# int fgetc(FILE *stream)
	#      read a character from input

	.align	8
	.globl	fgetc
fgetc:
	push	%rbx
	mov	%rdi,%rbx

	cmpq	$0,COUNT(%rbx)	# see if there is anyting in the buffer
	jne	1f

	call	fill		# nothing in buffer, better fill it
	xor	%rax,%rax
	cmpq	$0,COUNT(%rbx)
	je	2f		# still nothing in buffer, return 0

1:	xor	%rax,%rax
	mov	BPTR(%rbx),%rcx
	mov	(%rcx),%al
	inc	%rcx
	mov	%rcx,BPTR(%rbx)
	decq	COUNT(%rbx)
2:	pop	%rbx
	ret

	###########################################################################3
	#
	# void ungetc(int C, FILE *stream)
	#     put c back into stream
	#
	.align	8
	.globl	ungetc
ungetc:
	mov	BPTR(%rsi),%rax
	dec	%rax
	mov	%dil,(%rax)
	mov	%rax,BPTR(%rsi)
	incq	COUNT(%rsi)
	ret
	
	# int p_eoln(FILE *stream)
	#     test for end of line

	.globl	p_eoln
	.align	8
p_eoln:
	push	%rbx
	mov	%rdi,%rbx
	cmpq	$0,COUNT(%rbx)
	jne	1f  		# good
	call	fill		# no characters in buffer, read more
	xor	%rax,%rax
	cmpq	$0,COUNT(%rbx)
	sete	%al
	je	2f		# return 
1:	xor	%rax,%rax
	mov	BPTR(%rbx),%rcx
	cmpb	$'\n',(%rcx)
	sete	%al
2:	pop	%rbx
	ret
	
	# int p_eof(FILE *stream)
	#     test for end of file
	
	.globl	p_eof
	.align	8
p_eof:
	push	%rbx
	mov	%rdi,%rbx
	xor	%rax,%rax
	cmpq	%rax,COUNT(%rbx)
	jne	1f
	call	fill
	xor	%rax,%rax
	cmpq	$0,COUNT(%rbx)
	sete	%al
1:	pop	%rbx
	ret

	# int p_fflush(FILE *stream)
	#    flush output stream

	.globl	p_fflush
	.align	8
p_fflush:
	test	%rdi,%rdi
	jnz	1f
	call	flush_all
	jmp	2f
1:	xor	%rax,%rax
	mov	FLAGS(%rdi),%ecx
	and	$WRITE_MODE|TEXT_FILE,%ecx
	cmp	$WRITE_MODE|TEXT_FILE,%ecx
	jne	2f  				# must be a text file in write mode
	mov	BPTR(%rdi),%rdx
	mov	BUFF(%rdi),%rsi
	sub	%rsi,%rdx
	jz	2f
	mov	%rsi,BPTR(%rdi)
	mov	FD(%rdi),%edi
	call	p_write
2:	ret

	# void flush_all(void)
	#    call fflush on all files
	
	.globl	flush_all
	.align	8
flush_all:
	push	%rbx
	push	%r12
	mov	$NFILES,%rbx
	lea	files(%rip),%r12
1:	mov	%r12,%rdi
	call	p_fflush	# p_fflush checks to see if file is open and in write mode
	add	$FILE_TYPE_SIZE,%r12
	dec	%rbx
	jnz	1b
	pop	%r12
	pop	%rbx
	ret

	# void fill(FILE *stream)
	#     fill buffer for input text file
	.align
fill:
	push	%rbx
	mov	%rdi,%rbx
	mov	FD(%rbx),%edi
	mov	BUFF(%rbx),%rsi
	mov	%rsi,BPTR(%rbx)
	mov	$BUFF_SIZE,%rdx
	call	p_read
	xor	%rdx,%rdx
	testq	%rax,%rax
	cmovns	%rax,%rdx
	mov	%rdx,COUNT(%rbx)
	pop	%rbx
	ret
	
	# void spaces(long n, FILE *stream)
	#     print n spaces (' ') to stream

	.globl	spaces
	.align	8
spaces:
	push	%rbx
	push	%r12
	mov	%rdi,%rbx
	mov	%rsi,%r12
	test	%rbx,%rbx
	jle	1f
2:	mov	$' ',%edi
	mov	%r12,%rsi
	call	fputc
	dec	%rbx
	jnz	2b
1:	pop	%r12
	pop	%rbx
	ret

	.equ	CBUFF_SIZE,512	# way too big for integers, for reals, I don't know
	
	# a buffer for converting integers and reals to strings
	.bss
conv_buff:
	.zero	CBUFF_SIZE
	.text

	# char *convert_integer_to_ascii(long x)
	#    convert signed long to ascii string (base 10)

	.align	8
	.globl	convert_integer_to_ascii
convert_integer_to_ascii:
	test	%rdi,%rdi
	jns	1f
	neg	%rdi
	call	unsigned_to_ascii
	dec	%rax
	movb	$'-',(%rax)
	jmp	2f
1:	call	unsigned_to_ascii
2:	ret
	
	# char *unsigned_to_ascii(unsigned long x) {
	#    convert unsigned long to ascii string (base 10)
	#
	#    return a pointer to somewhere in conv_buff
	#    this should be used or copied before
	#    calling this routine again.

	.align	8
	.globl	unsigned_to_ascii  # remove this after testing
unsigned_to_ascii:
	
	# create string backwords
	
	lea	CBUFF_SIZE+conv_buff(%rip),%rsi
	
	# add null terminator to string

	dec	%rsi
	movb	$0,(%rsi)
	
	mov	$10,%rcx	# we're always dividing by 10

	# divide by 10 (the slow way [on many computers])

	mov	%rdi,%rax	# *--%rsi = x % 10 + '0'
	xor	%rdx,%rdx	# x /= 10
	div	%rcx
	mov	%rax,%rdi
	add	$'0',%dl
	dec	%rsi
	mov	%dl,(%rsi)

1:	test	%rdi,%rdi	# if %rdi == 0
	jz	2f		#     we're done

	mov	%rdi,%rax	# *--%rsi = x % 10 + '0'
	xor	%rdx,%rdx
	div	%rcx
	mov	%rax,%rdi
	add	$'0',%dl
	dec	%rsi
	mov	%dl,(%rsi)

	jmp	1b

2:	mov	%rsi,%rax
	ret
	
	
