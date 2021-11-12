	# Pascal standard library
	#    string.s (miscelaneous c string.h like routines
	
	# size_t p_strlen(const char *str)
	#    return the length of a string
	#        (c strings, not Pascal strings)
	.align	8
	.globl	p_strlen
p_strlen:
	xor	%rax,%rax
1:	mov	(%rdi),%sil
	test	%sil,%sil
	jz	2f
	inc	%rdi
	inc	%rax
	jmp	1b
2:	ret
	


	# int p_string_compare(int n, char *s1, char *s2)
	#    compare two Pascal strings of length n

	.align	8
	.globl	p_string_compare
p_string_compare:
	lea	(%rsi,%rdi),%rsi
	lea	(%rdx,%rdi),%rdx
	neg	%rdi
1:	mov	(%rsi,%rdi),%al
	sub	(%rdx,%rdi),%al
	jnz	2f
	inc	%rdi
	jnz	1b
2:	movsbq	%al,%rax
	ret
	
