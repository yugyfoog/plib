	# math.s -- math library for pascal
	#
	# most of these routines are hand compiled
	# from the Cephes Library (www.netlib.org/cephes/cmath.tgz)
	#

	######################################################################
	#
	# bool isnan(double x)
	#

	.align	8
	.globl	isnan
isnan:
	mov	$1,%rax
	xor	%rsi,%rsi
	vmovq	%xmm0,%rdi
	mov	%rdi,%rdx
	mov	$0x7ff0000000000000,%rcx
	and	%rcx,%rdx
	cmp	%rcx,%rdx
	cmovne	%rsi,%rax
	mov	$0x000fffffffffffff,%rcx
	and	%rcx,%rdi
	cmovz	%rsi,%rax
	ret

	######################################################################
	#
	# bool isfinite(double x)
	#   -- return not zero if x is not INF or NAN
	#
	
	.align	8
isfinite:
	xor	%rax,%rax
	movq	%xmm0,%rdi
	andn	infinity(%rip),%rdi,%rdi
	setnz	%al
	ret
	
	######################################################################
	#
	# double frexp(double x, int *e)
	#    -- split floating point into fraction and exponent
	#

	.align	8
	.globl	frexp
frexp:
	vmovq	%xmm0,%rax
	mov	$0x7ff0000000000000,%rcx
	andn	%rax,%rcx,%rdx
	mov	$0x3fe0000000000000,%rcx
	or	%rcx,%rdx
	vmovq	%rdx,%xmm0
	shr	$52,%rax
	sub	$0x3fe,%rax
	mov	%rax,(%rdi)
	ret

	##################################################################
	#
	# double ldexp(double x, int pw2)
	#    set pw2 to the binary exponent of x
	#
	# %xmm0 X (double)
	# %xmm1 TEMP (double)
	# %rdi  PW2 (int)
	# %rax  E (int)
	#
	
	.align	8
	.globl	ldexp
ldexp:	
	# u.y = x
	# q = (short *)&u.sh[3] 
	# while ((e = (*q&0x7ff0) >> 4) == 0)
1:	
	movq	%xmm0,%rax
	shr	$52,%rax
	and	$0x7ff,%rax
	jnz	6f
	
	#     -- input is denormal!
	#     if (u.y == 0.0)
	#         return 0.0

	comisd	zero(%rip),%xmm0
	jne	2f
	movsd	zero(%rip),%xmm0
	ret
	
2:	#     if (pw2 > 0)
	#         u.y *= 2.0
	#         pw2 -= 1
	
	cmp	$0,%rdi
	jle	3f
	mulsd	two(%rip),%xmm0
	dec	%rdi

3:	#     if (ps2 < 0)
	#         if (pw2 < -53)
	#             return 0.0
	#         u.y /= 2.0
	#         pw2 += 1
	
	test	%rdi,%rdi
	jns	5f
	cmp	$-53,%rdi
	jge	4f
	movsd	zero(%rip),%xmm0
	ret
4:	divsd	two(%rip),%xmm0
	inc	%rdi
	
5:	#     if pw2 == 0
	#         return u.y

	test	%rdi,%rdi
	jnz	1b
	ret
	
6:	# e += pw2

	add	%rdi,%rax
	
	# if e >= MEXP
	#     return INF

	cmp	$0x7ff,%rax
	jl	7f
	movsd	infinity(%rip),%xmm0
	ret

7:	# if e >= 1
	#     *q &= 0x800f
	#     *q |= (e & 0x7ff) << 4
	#     return u.y

	cmp	$1,%rax
	jl	8f
	andpd	mask1(%rip),%xmm0	# 0x800fffffffffffff
	and	$0x7ff,%rax
	shl	$52,%rax
	movq	%rax,%xmm1
	orpd	%xmm1,%xmm0
	ret
	
8:	# if e < -53
	#     return 0.0

	cmp	$-53,%rax
	jge	9f
	movsd	zero(%rip),%xmm0
	ret

9:	# *q &= 0x800f     save sign
	# *q |= 0x10       set most significant bit
	# u.y *= ldexp(1.0, e-1)
	# return u.y

	andpd	mask1(%rip),%xmm0	# 0x800fffffffffffff
	orpd	mask2(%rip),%xmm0   # 0x0010000000000000
	add	$0x3fe,%rax
	shl	$52,%rax
	movq	%rax,%xmm1
	mulsd	%xmm1,%xmm0
	ret
	
	####################################################################
	#
	# double floor(double x)
	#     return the largest integer <= x
	#

	.align	8
	.globl	floor
floor:

	# if abs(x) >= 2^52 (this should include inf, nan)
	#     return x

	movsd	%xmm0,%xmm1
	andpd	nnzero(%rip),%xmm1
	comisd	tp52(%rip),%xmm1
	jb	1f
	ret
	
1:	# y = (double)(long)x

	vcvttsd2si %xmm0,%rax
	vcvtsi2sd %rax,%xmm1,%xmm1

	# if y < 0 and y != x
	#    y -= 1.0
	# return y
	
	vcmpngesd	zero(%rip),%xmm0,%xmm2
	vcmpeqsd %xmm0,%xmm1,%xmm3
	andnpd	%xmm2,%xmm3
	andpd	one(%rip),%xmm2
	vsubsd	%xmm2,%xmm1,%xmm0
	ret
	
	# return y
	
	
	# else
	#     y = (double)(long)x
	#     if y != x
	#         return x - 1.0
	
	
	######################################################################
	#
	# double powi(double x, int nn)
	#   -- return x^n  (integer power)
	#
	# %xmm0   X
	# %rdi    NN		*-11
	# %xmm1   T (double)	5,10,14,18
	# %xmm2   W (double)	15-17
	# %xmm3   S (double)    9-14
	# %r10    E (int)	9-11
	# %rsi    N (int)       7-19
	# %rdx    LX (int)	9-11
	# %r8     ASIGN (int)	6-22
	# %r9	  SIGN (int)	7-20
	# %rax    TI2 (int)	9-10
	# %rcx    TI3 (int)	9-10
	# %xmm0   Y
	
	.align	8
	.globl	powi
powi:
	# if x == 0.0
	
	comisd	zero(%rip),%xmm0
	jne	1f

	#     if nn == 0

	test	%rdi,%rdi
	jne	2f

	#         return 1.0

	movsd	one(%rip),%xmm0
	ret

2:	#     else if nn < 0

	jns	3f

	#         return INFINITY

	movsd	infinity(%rip),%xmm0
	ret

3:	#     else if nn is odd
	#         return x  -- preserve sign of x

	test	$1,%rdi
	jz	4f
	ret

4:	#      else
	#          return 0.0

	xorpd	%xmm0,%xmm0
	ret

1:	# if nn == 0
	#     return 1.0
	
	test	%rdi,%rdi
	jne	5f
	movsd	one(%rip),%xmm0
	ret

5:	# if nn == 1
	#     return x
	
	cmp	$1,%rdi
	jne	22f
	ret
	
22:	# if nn == -1
	#     return 1.0/x

	cmp	$-1,%rdi
	jne	6f
	movsd	one(%rip),%xmm1
	vdivsd	%xmm0,%xmm1,%xmm0
	ret

6:	# if x < 0.0
	#     asign = -1
	#     x = -x
	# else
	#     asign = 0

	xor	%r8,%r8
	comisd	zero(%rip),%xmm0
	jae	7f
	dec	%r8
	xorpd	nzero(%rip),%xmm0
	
7:	# if nn < 0
	#     sign = -1
	#     n = -nn
	# else
	#     sign = 1
	#     n = nn

	mov	$1,%r9
	mov	%rdi,%rsi
	test	%rdi,%rdi
	jns	8f
	neg	%r9
	neg	%rsi

8:	# if n is even
	#     asign = 0

	test	$1,%rsi
	jnz	9f
	xor	%r8,%r8

9:	# s = frexp(x, &lx)
	#    -- do frexp inline to avoid function calls

	vmovq	%xmm0,%rdx
	mov	$0x7ff0000000000000,%rax
	andn	%rdx,%rax,%rcx
	mov	$0x3fe0000000000000,%rax
	or	%rax,%rcx
	vmovq	%rcx,%xmm3
	shr	$52,%rdx
	sub	$0x3fe,%rdx
	
	# e = (lx - 1)*n

	lea	-1(%rdx),%r10
	imul	%rsi,%r10

	# if (e == 0) or (e > 64) or (e < -64)

	mov	%r10,%rax		# check this
	add	$64,%rax
	cmp	$128,%rax
	ja	10f      # good
	test	%r10,%r10
	jnz	11f      # bad
	
10:	#     s = (s - sqrt(1/2)) / (s + sqrt(1/2))

	movsd	%xmm3,%xmm1
	subsd	sqrth(%rip),%xmm3
	addsd	sqrth(%rip),%xmm1
	divsd	%xmm1,%xmm3

	#     s = (2.9142135623730950*s - 1/2 + lx)*nn*ln(2)

	mulsd	powi1(%rip),%xmm3
	subsd	half(%rip),%xmm3
	vcvtsi2sd	%rdx,%xmm1,%xmm1
	addsd	%xmm1,%xmm3
	vcvtsi2sd	%rdi,%xmm1,%xmm1
	mulsd	%xmm1,%xmm3
	mulsd	loge2(%rip),%xmm3
	jmp	12f
	
11:	# else
	#     s = LOGE2*e
	vcvtsi2sd	%r10,%xmm3,%xmm3
	mulsd	loge2(%rip),%xmm3

12:	# if s > MAXLOG
	#     y = INFINITY
	#     goto done

	comisd	maxlog(%rip),%xmm3
	jbe 	13f
	movsd	infinity(%rip),%xmm0
	jmp	20f
	
13:	# if s < MINLOG
	#     y = 0.0
	#     goto done

	comisd	minlog(%rip),%xmm3
	jae	14f
	xorpd	%xmm0,%xmm0
	jmp	20f

14:	# if (s < -MAXLOG+2.0) and (sign < 0)
	#     x = 1.0/x
	#     sign = -sign

	comisd	nmaxlogp2(%rip),%xmm3
	jae	15f
	test	%r9,%r9
	jns	15f
	movsd	one(%rip),%xmm1
	vdivsd	%xmm0,%xmm1,%xmm0
	neg	%r9

15:	# w = x
	
	movsd	%xmm0,%xmm2

	# if n is odd
	#     y = x
	# else
	#     y = 1.0

	test	$1,%rsi
	jnz	16f
	movsd	one(%rip),%xmm0

16:	# n >>= 1

	shr	$1,%rsi

	# while (n)
17:	
	test	%rsi,%rsi
	jz	18f

	# w *= w

	mulsd	%xmm2,%xmm2

	# if n is odd
	#     y *= w

	test	$1,%rsi
	jz	19f
	mulsd	%xmm2,%xmm0

19:	shr	$1,%rsi
	jmp 17b

18:	# if sign < 0
	#     y = 1.0/y

	test	%r9,%r9
	jns	20f
	movsd	one(%rip),%xmm1
	vdivsd	%xmm0,%xmm1,%xmm0

20:	# done:

	# if asign
	#     if y == 0.0
	#         y = NEGZERO
	#     else
	#         y = -y

	test	%r8,%r8
	jz	21f
	comisd	zero(%rip),%xmm0
	jne	22f
	movsd	nzero(%rip),%xmm0
	jmp	21f
22:	xorpd	nzero(%rip),%xmm0

21:	# return y

	ret

	###################################################################
	# double exp(double x)
	#    -- return e to the power of x
	#
	#  -8(%rbp)  X (double)
	# -16(%rbp)  XX (double)
	# -24(%rbp)  PX (double)
	# %rbx       N (int)
	
	.align	8
	.globl	exp
exp:
	enter	$24,$0
	
	push	%rbx

	movsd	%xmm0,-8(%rbp)
	
	# if isnan(x)
	#     return x
	
	call	isnan
	test	%rax,%rax
	jz	1f
	movsd	-8(%rbp),%xmm0
	jmp	4f

1:	# if x > MAXLOG
	#     return INFINITY

	movsd	-8(%rbp),%xmm0
	comisd	maxlog(%rip),%xmm0
	jbe	2f
	movsd	infinity(%rip),%xmm0
	jmp	4f

2:	# if x < MINLOG
	#     return 0.0

	movsd	-8(%rbp),%xmm0
	comisd	minlog(%rip),%xmm0
	jae	3f
	xorpd	%xmm0,%xmm0
	jmp	4f

3:	# px = floor(LOG2E*x + 0.5)

	movsd	-8(%rbp),%xmm0
	mulsd	log2e(%rip),%xmm0
	addsd	half(%rip),%xmm0
	call	floor

	# n = px

	vcvttsd2si %xmm0,%rbx

	# x -= C1*px
	# x -= C2*px

	movsd	%xmm0,%xmm1
	movsd	-8(%rbp),%xmm2
	mulsd	c1(%rip),%xmm0
	subsd	%xmm0,%xmm2
	mulsd	c2(%rip),%xmm1
	subsd	%xmm1,%xmm2
	movsd	%xmm2,-8(%rbp)

	# xx = x*x

	mulsd	%xmm2,%xmm2
	movsd	%xmm2,-16(%rbp)

	# px = x*polev(xx, P, 2)

	movsd	%xmm2,%xmm0
	lea	Pexp(%rip),%rdi
	mov	$2,%rsi
	call	polevl
	mulsd	-8(%rbp),%xmm0
	movsd	%xmm0,-24(%rbp)

	# x = px/(polevl(xx, Q, 3) - px)

	movsd	-16(%rbp),%xmm0
	lea	Qexp(%rip),%rdi
	mov	$3,%rsi
	call	polevl
	movsd	-24(%rbp),%xmm1
	subsd	%xmm1,%xmm0
	divsd	%xmm0,%xmm1

	# x = 1.0 + 2.0*x

	mulsd	two(%rip),%xmm1
	addsd	one(%rip),%xmm1

	# x = ldexp(x, n)
	
	movsd	%xmm1,%xmm0
	mov	%rbx,%rdi
	call	ldexp

	# return x
4:	

	pop	%rbx
	leave
	ret

	###################################################################
	# double log(double x)
	#   -- return the natural logarithm of x
	#
	# -8(%rbp)  X (double)
	# -16(%rbp) Y (double)
	# -24(%rbp) Z (double)
	# -16(%rbp) ETEMP (int) must be on stack (share with Y)
	# %rbx      E (int) we need the address of E (this could alias Y or Z?)
	
	.align	8
	.globl	log
log:
	enter	$24,$0
	push	%rbx
	
	# if isnan(x)
	#     return x

	call	isnan
	test	%rax,%rax
	jnz	8f
	
	# if x == INFINITY
	#     return x

	comisd	infinity(%rip),%xmm0
	je	8f

	# if x <= 0.0
	#     if x == 0.0
	#         return -infinity
	#     else
	#         return nan
	
	comisd	zero(%rip),%xmm0
	ja	2f
	jne	1f
	movsd	ninfinity(%rip),%xmm0
	jmp	8f
1:	movsd	nan(%rip),%xmm0
	jmp	8f

2:	# x = frexp(x, &e)

	lea	-16(%rbp),%rdi
	call	frexp
	movsd	%xmm0,-8(%rbp)
	mov	-16(%rbp),%rbx

	# if e > 2 || e < -2

	lea	2(%rbx),%rax
	cmp	$4,%rax
	ja	5f

	#     if x < SQRTH
	#         e -= 1
	#         x = ldexp(x, 1) - 1.0
	#     else
	#         x -= 1.0
	
	movsd	-8(%rbp),%xmm0
	comisd	sqrth(%rip),%xmm0
	jae	3f
	dec	%rbx
	mov	$1,%rdx
	call	ldexp
3:
	subsd	one(%rip),%xmm0
	movsd	%xmm0,-8(%rbp)

	#     z = x*x

	mulsd	%xmm0,%xmm0
	movsd	%xmm0,-24(%rbp)

	#     y = x*(z*polevl(x, P, 5)/p1evl(x, Q, 5))

	movsd	-8(%rbp),%xmm0
	lea	Qlog(%rip),%rdi
	mov	$5,%rsi
	call	p1evl
	movsd	%xmm0,-16(%rbp)
	movsd	-8(%rbp),%xmm0
	lea	Plog(%rip),%rdi
	mov	$5,%rsi
	call	polevl
	mulsd	-24(%rbp),%xmm0
	divsd	-16(%rbp),%xmm0
	mulsd	-8(%rbp),%xmm0
	movsd	%xmm0,-16(%rbp)

	#     if e
	#         y -= e*2.121944400546905827679e-4

	test	%rbx,%rbx
	jz	4f
	vcvtsi2sd %rbx,%xmm0,%xmm0
	mulsd	logc1(%rip),%xmm0
	movsd	-16(%rbp),%xmm1
	subsd	%xmm0,%xmm1
	movsd	%xmm1,-16(%rbp)

4:	#     y -= ldexp(z, -1)

	movsd	-24(%rbp),%xmm0
	mov	$-1,%rdi
	call	ldexp
	movsd	-16(%rbp),%xmm1
	subsd	%xmm0,%xmm1

	#     z = x + y

	addsd	-8(%rbp),%xmm1
	
	#     if e
	#         z += e*0.693359375
	
	test	%rbx,%rbx
	jz	5f
	vcvtsi2sd %rbx,%xmm0,%xmm0
	mulsd	logc2(%rip),%xmm0
	addsd	%xmm1,%xmm0

	#     return z
	
	jmp	8f

5:	# else
	#     if x < SQRTH
	#         e -= 1
	#         z = x - 0.5
	#         y = 0.5*z + 0.5
	#     else
	#         z = x - 0.5
	#         z -= 0.5  ??? why?
	#         y = 0.5*x + 0.5

	movsd	-8(%rbp),%xmm0
	comisd	sqrth(%rip),%xmm0
	jae	6f
	dec	%rbx
	subsd	half(%rip),%xmm0
	movsd	%xmm0,-24(%rbp)
	mulsd	half(%rip),%xmm0
	addsd	half(%rip),%xmm0
	movsd	%xmm0,-16(%rbp)
	jmp	7f
6:
	subsd	one(%rip),%xmm0
	movsd	%xmm0,-24(%rbp)
	movsd	-8(%rbp),%xmm0
	mulsd	half(%rip),%xmm0
	addsd	half(%rip),%xmm0
	movsd	%xmm0,-16(%rbp)

7:	#     x = z/y

	movsd	-24(%rbp),%xmm0
	movsd	-16(%rbp),%xmm1
	divsd	%xmm1,%xmm0
	movsd	%xmm0,-8(%rbp)

	#     z = x*x

	mulsd	%xmm0,%xmm0
	movsd	%xmm0,-24(%rbp)

	# z = x*(z*polevl(z, R, 2)/p1evl(z, S, 3))

	lea	Rlog(%rip),%rdi
	mov	$2,%rsi
	call	polevl
	movsd	%xmm0,-16(%rbp)
	movsd	-24(%rbp),%xmm0
	lea	Slog(%rip),%rdi
	mov	$3,%rsi
	call	p1evl
	movsd	-16(%rbp),%xmm1
	divsd	%xmm0,%xmm1
	mulsd	-24(%rbp),%xmm1
	mulsd	-8(%rbp),%xmm1
	movsd	%xmm1,-24(%rbp)

	# z -= e*2.121944400546905827679e-4

	vcvtsi2sd %rbx,%xmm0,%xmm0
	mulsd	logc1(%rip),%xmm0
	movsd	-24(%rbp),%xmm1
	subsd	%xmm0,%xmm1

	# z += x
	
	addsd	-8(%rbp),%xmm1

	# z += e*0.693359375

	vcvtsi2sd %rbx,%xmm0,%xmm0
	mulsd	logc2(%rip),%xmm0
	addsd	%xmm0,%xmm1

	# return Z

	movsd	%xmm1,%xmm0

8:	
	
	pop	%rbx
	leave
	ret
	
	######################################################################
	# double log10(double x)
	#   -- return common logarithm of x
	#

	.align	8
	.globl	log10
log10:
	sub	$32,%rsp
	
	movsd	%xmm0,(%rsp)

	# if isnan(x)
	#    return x
	
	call	isnan
	test	%rax,%rax
	jz	1f
	movsd	(%rsp),%xmm0
	add	$32,%rsp
	ret
1:		
	# if x == INFINITY
	#     return x

	movsd	(%rsp),%xmm0
	comisd	infinity(%rip),%xmm0
	jne	2f
	movsd	(%rsp),%xmm0
	add	$32,%rsp
	ret
2:	
	# if x == 0
	#    return -INFINITY

	comisd	zero(%rip),%xmm0
	jne	3f
	movsd	ninfinity(%rip),%xmm0
	add	$32,%rsp
	ret
3:
	# if x < 0
	#     return NAN

	jg	4f
	movsd	nan(%rip),%xmm0
	add	$32,%rsp
	ret
4:
	# x = frexp(x, &e)

	lea	16(%rsp),%rdi
	call	frexp
	movsd	%xmm0,(%rsp)

	# if x < 1/sqrt(2)

	comisd	sqrth(%rip),%xmm0
	jae	5f

	#     e -= 1
	#     x = 2*x - 1
	
	decq	16(%rsp)
	movsd	(%rsp),%xmm0
	mulsd	two(%rip),%xmm0
	subsd	one(%rip),%xmm0
	movsd	%xmm0,(%rsp)
	jmp	6f
5:
	# else
	#    x -= 1.0

	movsd	(%rsp),%xmm0
	subsd	one(%rip),%xmm0
	movsd	%xmm0,(%rsp)
6:
	# z = x^2

	movsd	(%rsp),%xmm0
	mulsd	%xmm0,%xmm0
	movsd	%xmm0,8(%rsp)

	# T = z*polevl(x, P, 6)

	movsd	(%rsp),%xmm0
	lea	Plog10(%rip),%rdi
	mov	$6,%rsi
	call	polevl
	mulsd	8(%rsp),%xmm0
	movsd	%xmm0,24(%rsp)

	# Y = X*T/p1evl(x, Q, 6)

	movsd	(%rsp),%xmm0
	lea	Qlog10(%rip),%rdi
	mov	$6,%rsi
	call	p1evl
	movsd	24(%rsp),%xmm1
	divsd	%xmm0,%xmm1
	mulsd	(%rsp),%xmm1
	# %xmm1 == Y

	# y = y - Z/2

	movsd	8(%rsp),%xmm0
	mulsd	half(%rip),%xmm0  # would it be faster to decrement the exponent?
	subsd	%xmm0,%xmm1

	# z = (x+y)*log10(e)

	movsd	(%rsp),%xmm2
	vaddsd	%xmm2,%xmm1,%xmm0
	mulsd	l10eb(%rip),%xmm0
	mulsd	l10ea(%rip),%xmm1
	addsd	%xmm1,%xmm0
	mulsd	l10ea(%rip),%xmm2
	addsd	%xmm2,%xmm0

	# z += e*log10(2)
	
	vcvtsi2sdq 16(%rsp),%xmm2,%xmm2
	vmulsd	l102b(%rip),%xmm2,%xmm1
	addsd	%xmm1,%xmm0
	mulsd	l102a(%rip),%xmm2
	addsd	%xmm2,%xmm0

	add	$32,%rsp
	ret

	#####################################################################
	#
	# double sin(double x)
	#   -- return the sine of x
	#
	# -8(%rbp)  X (double)
	# -16(%rbp) Y double)
	# -24(%rbp) Z (double)
	# -32(%rbp) ZZ (double)
	# %r12      J (int)
	# %rbx      SIGN (int)
	
	.align	8
	.globl	sin
sin:
	enter	$32,$0
	push	%rbx
	push	%r12

	movsd	%xmm0,-8(%rbp)
	
	# if x == zero
	#     return x
	
	comisd	zero(%rip),%xmm0
	je	10f

	# if isnan(x)
	#      return x

	call	isnan
	test	%rax,%rax
	jz	1f
	movsd	-8(%rbp),%xmm0
	jmp	10f
	
1:	# if !isfinite(x)
	#     return nan

	movsd	-8(%rbp),%xmm0
	call	isfinite
	test	%rax,%rax
	jnz	2f
	movsd	nan(%rip),%xmm0
	jmp	10f

2:	# sign = 1
	# if x < 0
	#     x = -x
	#     sign = -1

	mov	$1,%rbx
	movsd	-8(%rbp),%xmm0
	comisd	zero,%xmm0
	jae	3f
	movsd	zero(%rip),%xmm1
	subsd	%xmm0,%xmm1
	movsd	%xmm1,-8(%rbp)
	neg	%rbx

3:	# if x > lossth
	#     return 0.0

	movsd	-8(%rbp),%xmm0
	comisd	lossth,%xmm0
	jbe	4f
	movsd	zero,%xmm0
	jmp	10f

4:	# y = floor(x/pio4)

	movsd	-8(%rbp),%xmm0
	divsd	pio4(%rip),%xmm0
	call	floor
	movsd	%xmm0,-16(%rbp)

	# z = ldexp(y,-4)
	# z = floor(z)
	# z = y - ldexp(z, 4)
	
	mov	$-4,%rdi
	call	ldexp
	call	floor
	mov	$4,%rdi
	call	ldexp
	movsd	-16(%rbp),%xmm1
	subsd	%xmm0,%xmm1
	movsd	%xmm1,-24(%rbp)

	# j = z

	vcvttsd2si %xmm1,%r12

	# if j & 1
	#      j += 1
	#      y += 1.0

	test	$1,%r12
	jz	5f
	inc	%r12
	movsd	-16(%rbp),%xmm0
	subsd	one(%rip),%xmm0

5:	# j &= 7
	# if j > 3
	#     sign = -sign
	#     j -= 4
	
	and	$7,%r12
	cmp	$3,%r12
	jbe	6f
	neg	%rbx
	sub	$4,%r12

6:	# z = ((x - y*DP1) - y*DP2) - y*DP3
	
	movsd	-8(%rbp),%xmm0
	movsd	-16(%rbp),%xmm1
	mulsd	dp1(%rip),%xmm1
	subsd	%xmm1,%xmm0
	movsd	-16(%rbp),%xmm1
	mulsd	dp2(%rip),%xmm1
	subsd	%xmm1,%xmm0
	movsd	-16(%rbp),%xmm1
	mulsd	dp3(%rip),%xmm1
	subsd	%xmm1,%xmm0
	movsd	%xmm0,-24(%rbp)

	# zz = z*z

	mulsd	%xmm0,%xmm0
	movsd	%xmm0,-32(%rbp)

	# if (j == 1) or (j == 2)
	#     y = 1.0 - ldexp(zz,-1) + zz*zz*polevl(zz, coscof, 5)

	dec	%r12
	cmp	$1,%r12
	ja	7f
	movsd	-32(%rbp),%xmm0
	lea	coscof(%rip),%rdi
	mov	$5,%rsi
	call	polevl
	mulsd	-32(%rbp),%xmm0
	mulsd	-32(%rbp),%xmm0
	movsd	%xmm0,-16(%rbp)
	movsd	-32(%rbp),%xmm0
	mov	$-1,%rdi
	call	ldexp
	movsd	one(%rip),%xmm1
	subsd	%xmm0,%xmm1
	addsd	-16(%rbp),%xmm1
	movsd	%xmm1,-16(%rbp)
	jmp	8f

7:	# else
	#     y = z + z*z*z*polevl(zz, sincof, 5)

	movsd	-32(%rbp),%xmm0
	lea	sincof(%rip),%rdi
	mov	$5,%rsi
	call	polevl
	mulsd	-24(%rbp),%xmm0
	mulsd	-24(%rbp),%xmm0
	mulsd	-24(%rbp),%xmm0
	addsd	-24(%rbp),%xmm0
	movsd	%xmm0,-16(%rbp)

8:	# if sign < 0
	#      y = -y

	test	%rbx,%rbx
	jge	9f
	movsd	-16(%rbp),%xmm0
	movsd	zero(%rip),%xmm1
	subsd	%xmm0,%xmm1
	movsd	%xmm1,-16(%rbp)

9:	# return y

	movsd	-16(%rbp),%xmm0

10:
	pop	%r12
	pop	%rbx
	leave
	ret
	
	#####################################################################
	#
	# double cos(double x)
	#   -- returns the cosine of x
	#
	
	.align	8
	.globl	cos
cos:
	enter	$40,$0
	push	%rbx
	push	%r12
	push	%r13
	
	movsd	%xmm0,-8(%rbp)
	
	# if isnan(x)
	#     return x
	
	movsd	-8(%rbp),%xmm0
	call	isnan
	test	%rax,%rax
	jz	1f
	movsd	-8(%rbp),%xmm0
	jmp	10f

1:	# if !isfinite(x)
	#     return NAN

	movsd	-8(%rbp),%xmm0
	call	isfinite
	test	%rax,%rax
	jnz	2f
	movsd	nan(%rip),%xmm0
	jmp	10f

2:	# sign = 1

	mov	$1,%rbx
	
	# if x < 0.0
	#     x = -x

	movsd	-8(%rbp),%xmm0
	andpd	nnzero(%rip),%xmm0
	movsd	%xmm0,-8(%rbp)
	
	# if x > lossth
	#     return 0.0

	comisd	lossth(%rip),%xmm0
	jb	3f
	movsd	zero(%rip),%xmm0
	jmp	10f

3:	# y = floor(x/PIO4)

	divsd	pio4(%rip),%xmm0
	vcvttsd2si %xmm0,%rax
	vcvtsi2sd %rax,%xmm0,%xmm0
	movsd	%xmm0,-16(%rbp)

	# z = ldexp(y, -4)

	movsd	-16(%rbp),%xmm0
	mov	$-4,%rdi
	call	ldexp

	# z = foor(z)
	
	vcvttsd2si %xmm0,%rax
	vcvtsi2sd %rax,%xmm0,%xmm0

	# z = y - ldexp(z, 4)
	
	mov	$4,%rdi
	call	ldexp
	movsd	-16(%rbp),%xmm1
	subsd	%xmm0,%xmm1
	movsd	%xmm1,-24(%rbp)

	# i = z

	vcvttsd2si %xmm1,%r12
	
	# if i&1
	#     i += 1
	#     y += 1.0

	test	$1,%r12
	jz	4f
	inc	%r12
	movsd	-16(%rbp),%xmm0
	addsd	one(%rip),%xmm0
	movsd	%xmm0,-16(%rbp)

4:	# j = i & 7

	mov	%r12,%r13
	and	$7,%r13

	# if j > 3
	#     j -= 4
	#     sign = -sign

	cmp	$3,%r13
	jle	5f
	sub	$4,%r13
	neg	%rbx

5:	# if j > 1
	#     sign = -sign

	cmp	$1,%r13
	jle	6f
	neg	%rbx

6:	# z = ((x - y*DP1) - y*DP2) - y*DP3
	movsd	-8(%rbp),%xmm0
	movsd	-16(%rbp),%xmm1
	mulsd	dp1(%rip),%xmm1
	subsd	%xmm1,%xmm0
	movsd	-16(%rbp),%xmm1
	mulsd	dp2(%rip),%xmm1
	subsd	%xmm1,%xmm0
	movsd	-16(%rbp),%xmm1
	mulsd	dp3(%rip),%xmm1
	subsd	%xmm1,%xmm0
	movsd	%xmm0,-24(%rbp)

	# zz = z*z

	mulsd	%xmm0,%xmm0
	movsd	%xmm0,-32(%rbp)

	# if (j == 1) or (j == 2)

	dec	%r13
	cmp	$1,%r13
	ja	7f

	#     y = z + z*z*z*polevl(zz,sincof, 5)

	movsd	-32(%rbp),%xmm0
	lea	sincof(%rip),%rdi
	mov	$5,%rsi
	call	polevl
	mulsd	-24(%rbp),%xmm0
	mulsd	-24(%rbp),%xmm0
	mulsd	-24(%rbp),%xmm0
	addsd	-24(%rbp),%xmm0
	movsd	%xmm0,-16(%rbp)
	jmp	8f

7:	# else
	#     y = 1.0 - ldexp(zz,-1) + zz*zz*polevl(zz, coscof, 5)

	movsd	-32(%rbp),%xmm0
	lea	coscof,%rdi
	mov	$5,%rsi
	call	polevl
	mulsd	-32(%rbp),%xmm0
	mulsd	-32(%rbp),%xmm0
	movsd	%xmm0,-40(%rbp)
	movsd	-32(%rbp),%xmm0
	mov	$-1,%rdi
	call	ldexp
	movsd	one(%rip),%xmm1
	subsd	%xmm0,%xmm1
	addsd	-40(%rbp),%xmm1
	movsd	%xmm1,-16(%rbp)
	
8:	# if sign < 0
	#     y = -y

	test	%rbx,%rbx
	jns	9f
	movsd	-16(%rbp),%xmm0
	xorpd	nzero(%rip),%xmm0
	movsd	%xmm0,-16(%rbp)

9:	# return y

	movsd	-16(%rbp),%xmm0
10:	
	pop	%r13
	pop	%r12
	pop	%rbx
	leave
	ret
	
	#####################################################################
	#
	# double atan(double x)
	#   -- returns the arctangent of x
	#
	# %xmm0  X (double)
	# %xmm1  Y (double)
	# %xmm2  Z (double)
	# %xmm3  TEMP (double)
	# %rbx   SIGN (int)
	# %r12   FLAG (int)
	# (%rsp)   SAVEX
	# 8(%rsp)  SAVEY
	# 16(%rsp) SAVEZ
	
	.align	8
	.globl	atan
atan:
	push	%rbx
	push	%r12
	sub	$24,%rsp

	
	# if x == 0.0
	#     return x  (preserve minus zero)

	comisd	zero(%rip),%xmm0
	je	10f

	# if x == infinity
	#     return pi/2

	comisd	infinity(%rip),%xmm0
	jne	1f
	movsd	pio2(%rip),%xmm0
	jmp	10

1:	# if x == -infinity
	#     return -pi/2

	comisd	ninfinity(%rip),%xmm0
	jne	2f
	movsd	npio2(%rip),%xmm0
	jmp	10

2:	# sign = 1
	# if x < 0.0
	#     sign = -1
	#     x = -x
	
	mov	$1,%rbx
	comisd	zero(%rip),%xmm0
	jae	3f
	mov	$-1,%rbx
	andpd	nnzero(%rip),%xmm0

3:	# flag = 1
	# if x > t3p8
	#     y = PIO2
	#     flag = 2
	#     x = -(1.0/x)

	mov	$1,%r12
	comisd	t3p8(%rip),%xmm0
	jbe	4f
	movsd	pio2,%xmm1
	mov	$2,%r12
	movsd	none(%rip),%xmm3
	divsd	%xmm0,%xmm3
	movsd	%xmm3,%xmm0
	jmp	6f

4:	# else if x <= 0.66
	#     y = 0.0

	comisd	zp66(%rip),%xmm0
	ja	5f
	movsd	zero(%rip),%xmm1
	jmp	6f

5:	# else
	#     y = pio4
	#     flag = 3
	#     x = (x - 1.0)/(x + 1.0)

	movsd	pio4(%rip),%xmm1
	mov	$3,%r12
	movsd	%xmm0,%xmm3
	subsd	one(%rip),%xmm0
	addsd	one(%rip),%xmm3
	divsd	%xmm3,%xmm0

6:	# z = x*x

	movsd	%xmm0,%xmm2
	mulsd	%xmm0,%xmm2

	# z = z*polevl(z, P, 4)/p1evl(z, Q, 5)
	
	movsd	%xmm0,(%rsp)
	movsd	%xmm1,8(%rsp)
	movsd	%xmm2,16(%rsp)

	movsd	%xmm2,%xmm0
	lea	Patan(%rip),%rdi
	mov	$4,%rsi
	call	polevl
	movsd	16(%rsp),%xmm1
	mulsd	%xmm1,%xmm0
	movsd	%xmm0,16(%rsp)
	movsd	%xmm1,%xmm0
	lea	Qatan(%rip),%rdi
	mov	$5,%rsi
	call	p1evl
	movsd	16(%rsp),%xmm1
	divsd	%xmm0,%xmm1

	# z = x*z + x

	mulsd	(%rsp),%xmm1	# z is now %xmm1
	addsd	(%rsp),%xmm1

	# if flag == 3
	#     z += 0.5*morebits
	# else if flag == 2
	#     z += morebits

	dec	%r12
	jz	8
	movsd	morebits(%rip),%xmm3
	dec	%r12
	jz	7f
	divsd	two(%rip),%xmm3
7:	addsd	%xmm3,%xmm1
	
8:	# y = y + z
	
	addsd	8(%rsp),%xmm1	# y is now %xmm1

	# if sign < 0
	#     y = -y

	test	%rbx,%rbx
	jns	9f
	xorpd	nzero(%rip),%xmm1
	
9:	# return y

	movsd	%xmm1,%xmm0
10:	
	add	$24,%rsp
	pop	%r12
	pop	%rbx
	ret
	
	######################################################################
	#
	# double polevl(double x, double *coef, int n)
	#   -- evaluate polynomial
	#
	# %xmm1    X      double
	# %rdi     COEF   *double
	# %rsi     N      int
	# %rdi     P      *double
	# %xmm0    ANS    double
	# %rsi     I      int

	.align	8
polevl:

	movsd	%xmm0,%xmm1
	
	# p = coef
	# ans = *p++

	movsd	(%rdi),%xmm0
	add	$8,%rdi

	# i = n
	# do
1:
	#     ans = ans*x + *p++

	mulsd	%xmm1,%xmm0
	addsd	(%rdi),%xmm0
	add	$8,%rdi
	
	# while --i

	dec	%rsi
	jnz	1b

	# return ans

	ret

	######################################################################
	# double p1evl(double x, double *coef, int n)
	#   evaluate polynomial when coefficient of x^n is 1.0
	#
	
	.align	8
p1evl:
	movsd	%xmm0,%xmm1

	# p = coef
	# ans = x + *p++
	
	movsd	(%rdi),%xmm0
	addsd	%xmm1,%xmm0
	add	$8,%rdi

	# i = n-1

	dec	%rsi

	# do
1:
	#    ans = ans*x + *p++

	mulsd	%xmm1,%xmm0
	addsd	(%rdi),%xmm0
	add	$8,%rdi

	# while --i

	dec	%rsi
	jnz	1b

	# return ans
	
	ret

	.align	8
zero:	.quad	0
	.align	16
nzero:	.quad	0x8000000000000000
	.quad	0			# padding for *pd instructions
	.align	16
nnzero:	.quad	0x7fffffffffffffff	# inverse of nzero
	.quad	0
infinity:	.quad	0x7ff0000000000000
ninfinity:	.quad	0xfff0000000000000
nan:		.quad	0x7ff8000000000000
	.align	16
mask1:	.quad	0x800fffffffffffff
	.quad	0
mask2:	.quad	0x0010000000000000
	.quad	0
	.align	16
one:	.quad	0x3ff0000000000000	# 1.0
	.quad	0			# padding for *pd instructions
none:	.quad	0xbff0000000000000	# -1.0
two:	.quad	0x4000000000000000	# 2.0
half:	.quad	0x3fe0000000000000	# 0.5
tp52:	.quad	0x4330000000000000	# 2^52
lossth:	.quad	0x41d0000000000000	# 2^30
sqrth:	.quad	0x3fe6a09e667f3bcd	# 1/sqrt(2)
loge2:	.quad	0x3fe62e42fefa39ef	# log(2)
log2e:	.quad	0x3ff71547652b82fe	# log_2(e)
pi:	.quad	0x400921fb54442d18	# pi
pio2:	.quad	0x3ff921fb54442d18	# pi/2
npio2:	.quad	0xbff921fb54442d18	# -pi/2
pio4:	.quad	0x3fe921fb54442d18	# pi/4
t3p8:	.quad	0x4003504f333f9de6	# 3*pi/8
powi1:	.quad	0x4007504f333f9de6	# 2.9142135623730950
minlog:	.quad	0xc0874910d52d3052	# log(2**-1074)
maxlog:	.quad	0x40862e42fefa39ef	# log(2**1024)
nmaxlogp2: .quad	0xc0861e42fefa39ef	# 2 - maxlog
l10ea:	.quad	0x3fdbc00000000000	# l10ea + l10eb = log10(e)
l10eb:	.quad	0x3f46f62a4dca1c65
l102a:	.quad	0x3fd3400000000000	# l012a + l102b = log10(2)
l102b:	.quad	0x3f304d427de7fbcc
	
morebits: .quad	0x3c91a62633145c07	# 6.12323399573676588613e-17
zp66:	.quad	0x3fe51eb851eb851f	# 0.66
dp1:	.quad	0x3fe921fb40000000	# 7.85398125648498535156e-1
dp2:	.quad	0x3e64442d00000000	# 3.77489470793079817668e-8
dp3:	.quad	0x3ce8469898cc5170	# 2.69515142907905952645e-15
c1:	.quad	0x3fe62e4000000000	# 6.93145751953125e-1
c2:	.quad	0x3eb7f7d1cf79abca	# 1.42860682030941723212e-6
logc1:	.quad	0x3f2bd0105c610ca8	# 2.121944400546905827579e-4
logc2:	.quad	0x3fe6300000000000	# 0.693359375
	
	# P for exp
Pexp:	.quad	0x3f2089cdd5e44be8
	.quad	0x3f9f06d10cca2c7e
	.quad	0x3ff0000000000000

	# Q for exp
Qexp:	.quad	0x3ec92eb6bc365fa0
	.quad	0x3f64ae39b508b6c0
	.quad	0x3fcd17099887e074
	.quad	0x4000000000000000

	# P for log

Plog:	.quad	0x3f1ab4c293c31bb0
	.quad	0x3fdfd6f53f5652f2
	.quad	0x4012d2baed926911
	.quad	0x402cff72c63eeb2e
	.quad	0x4031efd6924bc84d
	.quad	0x401ed5637d7edcf8

	# Q for log

Qlog:	.quad	0x40269320ae97ef8e
	.quad	0x40469d2c4e19c003
	.quad	0x4054bf33a326bdbd
	.quad	0x4051c9e2eb5eae21
	.quad	0x4037200a9e1f25b2

	# R for log

Rlog:	.quad	0xbfe9443ddc6c0e84
	.quad	0x403062fc73027b6b
	.quad	0xc050090611222a20

	# S for log

Slog:	.quad	0xc041d60d43ec6d0a
	.quad	0x40738180112ae40e
	.quad	0xc0880d8919b33f3b
	
	# P for log10

Plog10:	.quad	0x3f0809a76a5f974f 
	.quad	0x3fdfe7eed9795a1a
	.quad	0x401a40a2c66c74c9
	.quad	0x403dc9a97e3d411d
	.quad	0x404e4e6d64ebdcdc
	.quad	0x404c5e122519d312
	.quad	0x4033e3a589b13130
	
	# Q for log10
	
Qlog10:	.quad	0x402e10160dfbd0a2
	.quad	0x4054af6d47ae79c7
	.quad	0x406b9542a44b455a
	.quad	0x40733411298310d7
	.quad	0x406ade942a8d3423
	.quad	0x404dd5784e89c9c8

	# P for atan

Patan:	.quad	0xbfec007fa1f72594
	.quad	0xc03028545b6b807a
	.quad	0xc052c08c36880273
	.quad	0xc05eb8bf2d05ba25
	.quad	0xc0503669fd28ec8e
	
	# Q for atan

Qatan:	.quad	0x4038dbc45b14603c
	.quad	0x4064a0dd43b8fa25
	.quad	0x407b0e18d2e2be3b
	.quad	0x407e563f13b049ea
	.quad	0x4068519efbbd62ec
	
sincof:	.quad	0x3de5d8fd1fd19ccd
	.quad	0xbe5ae5e5a9291f5d
	.quad	0x3ec71de3567d48a1
	.quad	0xbf2a01a019bfdf03
	.quad	0x3f8111111110f7d0
	.quad	0xbfc5555555555548

coscof:	.quad	0xbda8fa49a0861a9b
	.quad	0x3e21ee9d7b4e3f05
	.quad	0xbe927e4f7eac4bc6
	.quad	0x3efa01a019c844f5
	.quad	0xbf56c16c16c14f91
	.quad	0x3fa555555555554b
	
