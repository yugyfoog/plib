	# Pascal standard library
	#   transfer functions
	#      interface Pascal abi to C abi

	.align	8
	.globl	close_x
close_x:
	mov	8(%rsp),%rdi
	call	p_close
	ret	$8

	.align	8
	.globl	exit_x
exit_x:
	mov	8(%rsp),%rdi
	call	exit
	# does not return
	
	.align	8
	.globl	named_reset_text_x
named_reset_text_x:
	mov	8(%rsp),%rdi
	mov	16(%rsp),%rsi
	mov	24(%rsp),%rdx
	call	named_reset_text
	ret	$24

	.align	8
	.globl	named_rewrite_text_x
named_rewrite_text_x:
	mov	8(%rsp),%rdi
	mov	16(%rsp),%rsi
	mov	24(%rsp),%rdx
	call	named_rewrite_text
	ret	$24
	
	.align	8
	.globl	read_char_x
read_char_x:
	mov	8(%rsp),%rdi
	mov	16(%rsp),%rsi
	call	read_character
	ret	$16

        .align  8
        .globl  read_integer_x
read_integer_x:
        mov     8(%rsp),%rdi
        mov     16(%rsp),%rsi
        call    read_integer
        ret     $16
        
	.align	8
	.globl	read_real_x
read_real_x:
	mov	8(%rsp),%rdi
	mov	16(%rsp),%rsi
	call	read_real
	ret	$16
	
	.align	8
	.globl	readln_x
readln_x:
	mov	8(%rsp),%rdi
	call	readln
	ret $8

	.align	8
	.globl	write_boolean_x
write_boolean_x:
	mov	8(%rsp),%rdi
	mov	16(%rsp),%rsi
	mov	24(%rsp),%rdx
	call	write_boolean
	ret	$24
	
	.align	8
	.globl	write_char_x
write_char_x:
	mov	8(%rsp),%rdi
	mov	16(%rsp),%rsi
	mov	24(%rsp),%rdx
	call	write_character
	ret $24
	
	.align	8
	.globl	write_integer_x
write_integer_x:
	mov	8(%rsp),%rdi
	mov	16(%rsp),%rsi
	mov	24(%rsp),%rdx
	call	write_integer
	ret	$24

	.align	8
	.globl	write_string_x
write_string_x:
	mov	8(%rsp),%rdi
	mov	16(%rsp),%rsi
	mov	24(%rsp),%rdx
	mov	32(%rsp),%rcx
	call	write_string
	ret	$32

	.align	8
	.globl	write_real_float_x
write_real_float_x:
	mov	8(%rsp),%rdi
	movsd	16(%rsp),%xmm0
	mov	24(%rsp),%rsi
	call	p_write_real_float
	ret	$24
	
	.align	8
	.globl	writeln_x
writeln_x:
	mov	8(%rsp),%rdi
	call	writeln
	ret	$8
	
	.align	8
	.globl	eof_x
eof_x:	mov	8(%rsp),%rdi
	call	p_eof
	ret	$8

	.align	8
	.globl	eoln_x
eoln_x:	mov	8(%rsp),%rdi
	call	p_eoln
	ret	$8

	.align	8
	.globl	flush_x
flush_x: mov	8(%rsp),%rdi
	call	p_fflush
	ret	$8
	
	.align	8
	.globl	argv_x
argv_x:	mov	8(%rsp),%rdi
	mov	16(%rsp),%rsi
	mov	24(%rsp),%rdx
	call	argv
	ret	$24
	
	.align	8
	.globl	p_string_compare_x
p_string_compare_x:
	mov	8(%rsp),%rdi
	mov	16(%rsp),%rsi
	mov	24(%rsp),%rdx
	call	p_string_compare
	ret	$24
	
	.align	8
	.globl	p_new_x
p_new_x:
	mov	8(%rsp),%rdi
	mov	16(%rsp),%rsi
	call	p_new
	ret	$16

	.align	8
	.globl	p_dispose_x
p_dispose_x:
	mov	8(%rsp),%rdi
	call	p_free
	ret	$8

	.align	8
	.globl	exp_x
exp_x:
	movsd	8(%rsp),%xmm0
	call	exp
	movq	%xmm0,%rax
	ret	$8

	.align	8
	.globl	ln_x
ln_x:
	movsd	8(%rsp),%xmm0
	call	log
	movq	%xmm0,%rax
	ret	$8

	.align	8
	.globl	sin_x
sin_x:
	movsd	8(%rsp),%xmm0
	call	sin
	movq	%xmm0,%rax
	ret	$8
	
	.align	8
	.globl	cos_x
cos_x:
	movsd	8(%rsp),%xmm0
	call	cos
	movq	%xmm0,%rax
	ret	$8
	
	.align	8
	.globl	arctan_x
arctan_x:
	movsd	8(%rsp),%xmm0
	call	atan
	movq	%xmm0,%rax
	ret	$8
	
	
