	# pascal standard library
	#    stdlib.s (miscelaneous c stdlib.h like routines)


	
	.equ	NALLOC,4096     # system block size

	# parameters for mmap
	
	.equ	PROT_READ,1	
	.equ	PROT_WRITE,2
	.equ	MAP_SHARED,1
	.equ	MAP_ANON,32


	# struct header {
	#    void *mem
	#    unsigned long size
	#
	
	.equ	HEADER.NEXT,0
	.equ	SIZE,8

	.bss
	.align	8
base:	.zero	16
freep:	.zero	8
	.text

	# void p_new(void *mem, long size)
	.globl	p_new
	.align	8
p_new:	push	%rbx
	mov	%rdi,%rbx
	mov	%rsi,%rdi
	call	p_malloc
	mov	%rax,(%rbx)
	pop	%rbx
	ret
	
	# void *p_malloc(unsigned long bytes)
	#    allocate memory
	#    %rbx -- size (in sizeof(Header) units) of memmory needed
	#    %r12 -- pointer to current free block in list
	#    %r13 -- pointer to previous free block in list

	
	.globl	p_malloc
	.align	8
p_malloc:
	push	%rbx
	push	%r12
	push	%r13
	
	lea	15(%rdi),%rbx		# convert bytes to sizeof(Header) units 
	shr	$4,%rbx			#     (rounding up)
	inc	%rbx			# add one for the header

	mov	freep(%rip),%r13
	test	%r13,%r13
	jnz	1f
	
	# first time malloc is called freep is zero
	#      initialize base to a zero sized block
	#      with it self as the next block
	
	lea	base(%rip),%r13
	mov	%r13,freep(%rip)
	mov	%r13,base(%rip)
	xor	%rax,%rax
	mov	%rax,base+8(%rip)
	
1:	mov	(%r13),%r12
2:	# for loop
	cmp	%rbx,SIZE(%r12)
	jb	3f
	ja	4f
	# exact match
	mov	(%r12),%rax		# remove current block from free list
	mov	%rax,(%r13)
	jmp	5f
4:	# not exact match split block
	mov	SIZE(%r12),%rax
	sub	%rbx,%rax
	mov	%rax,SIZE(%r12)
	shl	$4,%rax
	add	%rax,%r12		# %r12 now points to new block (the one we return)
	mov	%rbx,SIZE(%r12) # set size of new block
	# we don't need to set HEADER.NEXT(%r12) since we're not putting it on the free list
5:	# prepare to return
	mov	%r13,freep(%rip)
	lea	16(%r12),%rax
7:	pop	%r13
	pop	%r12
	pop	%rbx
	ret

3:	# current (%r12) too small, check next
	cmp	freep(%rip),%r12
	jne	6f
	mov	%rbx,%rdi
	call	more_core
	mov	%rax,%r12
	test	%rax,%rax
	jnz	6f
	jmp	7b		# no more memory, :(, return NULL
	
6:	# next free block
	mov	%r12,%r13
	mov	(%r12),%r12
	jmp	2b

	
	# void p_free(void *ap)
	#    free allocated globl
	.globl	p_free
	.align	8
p_free:
	test	%rdi,%rdi
	je	9f			# free(0) should do nothing
	
	lea	-16(%rdi),%rdi	# %rdi to point to header before block
	# the header (which %rdi points to) has the size of the block that we're freeing
	# the NEXT part is garbage

	# find the highest free block lower than the block we're freeing

	mov	freep(%rip),%rdx	# get the start of the free list
4:	cmp	%rdi,%rdx		# if %rdx < %rdi < *%rdx then  we found our spot
	ja	1f
	cmp	(%rdx),%rdi
	jb	2f
	
1:	cmp	(%rdx),%rdx		# if %rdx >= *%rdx  and  (%rdx < %rdi or %rdi < *%rdx) then block
	jb	3f			#     to be freed is before first or after last
	cmp	%rdi,%rdx 		#     block
	jb	2f
	cmp	(%rdx),%rdi
	jb	2f
	
3:	mov	(%rdx),%rdx		# next element on list
	jmp	4b

2:	# got out location now

	mov	SIZE(%rdi),%rax	# if %rdi + %rdi->SIZE == %rdx->NEXT
	shl	$4,%rax
	add	%rdi,%rax
	cmp	(%rdx),%rax
	jne	5f

	mov	(%rdx),%rax		# merge block to following block
	mov	SIZE(%rax),%rcx
	add	%rcx,SIZE(%rdi)
	mov	(%rax),%rcx
	mov	%rcx,(%rdi)
	jmp	6f
5:	mov	(%rdx),%rax
	mov	%rax,(%rdi)
	
6:	mov	SIZE(%rdx),%rax	# if %rdx + %rdx->SIZE == %rdi
	shl	$4,%rax
	add	%rdx,%rax
	cmp	%rdi,%rax
	jne	7f

	mov	SIZE(%rdi),%rax	# merge block to preceding block
	add	%rax,SIZE(%rdx)
	mov	(%rdi),%rax
	mov	%rax,(%rdx)
	jmp	8f
7:	mov	%rdi,(%rdx)
	
8:	mov	%rdx,freep(%rip)	# save newly freed block as the
					# first to search for in malloc
9:	ret
	
	# void *more_core(unsigned long nu)
	#    grab memory from OS
	
	.globl	more_core
	.align	8
more_core:
	push	%rbx
	dec	%rdi
	or	$0xff,%rdi
	inc	%rdi
	mov	%rdi,%rbx
	shl	$4,%rdi
	mov	%rdi,%rsi
	xor	%rdi,%rdi
	mov	$PROT_READ+PROT_WRITE,%rdx
	mov	$MAP_ANON+MAP_SHARED,%rcx
	mov	$-1,%r8
	xor	%r9,%r9
	call	p_mmap
	test	%rax,%rax
	jns	1f
	xor	%rax,%rax
	jmp	2f
1:	mov	%rbx,SIZE(%rax)
	lea	16(%rax),%rdi
	call	p_free                  # use free to put new memory into free list
	mov	freep(%rip),%rax
2:	pop	%rbx
	ret

	# void exit(int status)
	#    flush files and exit program

	.globl	exit
	.align	8
exit:
	push	%rdi		# save exit parameter
	call	flush_all	# flush all output files
	pop	%rdi
	call	_exit
	# does not return
	
	

	
