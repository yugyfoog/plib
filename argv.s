	.bss
	.align	8
	.globl	p_argc
p_argc:	.zero	8
	.globl	p_argv
p_argv:	.zero	8	
	.text
	.align	8
	.globl	argv
	#  void argv(long n, char *arg, long len)
	#      write command-line argument n (argv[n]) to arg[len]
argv:
	mov	p_argv,%rax
	mov	(%rax,%rdi,8),%rax
1:	mov	(%rax),%cl
	test	%cl,%cl
	jz	2f
	mov	%cl,(%rsi)
	inc	%rax
	inc	%rsi
	dec	%rdx
	jnz	1b
	jmp	3f
2:	# %cl is zero here
	mov	%cl,(%rsi)
	inc	%rsi
	dec	%rdx
	jnz	2b
3:	ret
	
	
