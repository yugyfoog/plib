	# Pascal standard library
	# linux.s -- linux (x86-64) system calls

	.equ	SYS_READ,0
	.equ	SYS_WRITE,1
	.equ	SYS_OPEN,2
	.equ	SYS_CLOSE,3
	.equ	SYS_MMAP,9
	.equ	SYS_EXIT,60
	
	.bss
	.align	8
	.globl	p_errno
p_errno: .zero	8
	.text
	.align	8
sys_call:
	mov	%rcx,%r10
	syscall
	test	%rax,%rax
	js	1f
	ret
1:	mov	%rax,p_errno(%rip)
	mov	$-1,%rax
	ret
	
	.globl	_exit
	.align	8
_exit:
	mov	$SYS_EXIT,%rax
	jmp	sys_call
	
	.globl	p_mmap
	.align	8
p_mmap:
	mov	$SYS_MMAP,%rax
	jmp	sys_call

	.globl	p_open
	.align	8
p_open:	
	mov	$SYS_OPEN,%rax
	jmp	sys_call

	.globl	sys_close
sys_close:
	mov	$SYS_CLOSE,%rax
	jmp	sys_call
	
	.globl	p_write
	.align	8
p_write:
	mov	$SYS_WRITE,%rax
	jmp	sys_call

	.globl	p_read
	.align	8
p_read:
	mov	$SYS_READ,%rax
	jmp	sys_call
	
