	# Pascal standard library
	#   error.s -- error handling routines

	.align	8    
error_msg:
	.string	"fatal error: "

	# void pascal_error(char *)
	#     print error message and die

	.align	8
	.globl	pascal_error
pascal_error:
	# no need to save %rbx since we never return

	mov	%rdi,%rbx
	lea	error_msg(%rip),%rdi
	lea	error(%rip),%rsi
	call	fputs
	mov	%rbx,%rdi
	lea	error(%rip),%rsi
	call	fputs
	mov	$'\n',%edi
	lea	error(%rip),%rsi
	call	fputc
	mov	$1,%rdi
	call	exit
	# no return

	.align	8
	.globl	case_error
case_error:
	lea	case_error_message(%rip),%rdi
	jmp	pascal_error

	.align	8
case_error_message:	
	.string	"case error"

	
