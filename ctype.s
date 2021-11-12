	.equ	CT_CNTRL,1
	.equ	CT_SPACE,2
	.equ	CT_BLANK,4
	.equ	CT_UPPER,8
	.equ	CT_LOWER,16
	.equ	CT_DIGIT,32
	.equ	CT_XDIGIT,64


	# iscntrl = !isprint
	# isgraph = isprint && !isspace
	# ispunct = isprint && !isspace && !isalnum
	# isalnum = isupper || islower || isdigit
	# isalpha = isupper || islower

	.align	8
	.globl	iscntrl
iscntrl:
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_CNTRL,%al
	ret

	.align	8
	.globl	isprint
isprint:
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_CNTRL,%al
	setz	%al
	ret

	.align	8
	.globl	isspace
isspace:	
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_SPACE,%al
	ret

	.align	8
	.globl	isblank
isblank:
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_BLANK,%al
	ret

	.align	8
	.globl	isgraph
isgraph:
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_CNTRL|CT_SPACE,%al
	setz	%al
	ret
	
	.align	8
	.globl	ispunct
ispunct:
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_CNTRL|CT_SPACE|CT_DIGIT|CT_UPPER|CT_LOWER,%al
	setz	%al
	ret

	.align	8
	.globl	isalnum
isalnum:
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_DIGIT|CT_UPPER|CT_LOWER,%al
	ret

	.align	8
	.globl	isalpha
isalpha:
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_UPPER|CT_LOWER,%al
	ret

	.align	8
	.globl	isupper
isupper:
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_UPPER,%al
	ret

	.align	8
	.globl	islower
islower:
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_LOWER,%al
	ret

	.align	8
	.globl	isdigit
isdigit:
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_DIGIT,%al
	ret

	.align	8
	.globl	isxdigit
isxdigit:
	xor	%rax,%rax
	mov	ctype(%rdi),%al
	and	$CT_XDIGIT,%al
	ret

	.align	8

ctype:	.byte	CT_CNTRL			# NUL
	.byte	CT_CNTRL			# SOH
	.byte	CT_CNTRL			# STX
	.byte	CT_CNTRL			# ETX
	.byte	CT_CNTRL			# EOT
	.byte	CT_CNTRL			# ENQ
	.byte	CT_CNTRL			# ACK
	.byte	CT_CNTRL			# BEL
	.byte	CT_CNTRL			# BS
	.byte	CT_CNTRL|CT_SPACE|CT_BLANK	# HT
	.byte	CT_CNTRL|CT_SPACE		# LF
	.byte	CT_CNTRL|CT_SPACE		# VT
	.byte	CT_CNTRL|CT_SPACE		# FF
	.byte	CT_CNTRL|CT_SPACE		# CR
	.byte	CT_CNTRL			# SO
	.byte	CT_CNTRL			# SI
	.byte	CT_CNTRL			# DLE
	.byte	CT_CNTRL			# DC1
	.byte	CT_CNTRL			# DC2
	.byte	CT_CNTRL			# DC3
	.byte	CT_CNTRL			# DC4
	.byte	CT_CNTRL			# NAK
	.byte	CT_CNTRL			# SYN
	.byte	CT_CNTRL			# ETB
	.byte	CT_CNTRL			# CAN
	.byte	CT_CNTRL			# EM
	.byte	CT_CNTRL			# SUB
	.byte	CT_CNTRL			# ESC
	.byte	CT_CNTRL			# FS
	.byte	CT_CNTRL			# GS
	.byte	CT_CNTRL			# RS
	.byte	CT_CNTRL			# US
	.byte	CT_SPACE|CT_BLANK		# ' '
	.byte	0				# '!'
	.byte	0				# '\"'
	.byte	0				# '#'
	.byte	0				# '$'
	.byte	0				# '%'
	.byte	0				# '&'
	.byte	0				# '\''
	.byte	0				# '('
	.byte	0				# ')'
	.byte	0				# '*'
	.byte	0				# '+'
	.byte	0				# ','
	.byte	0				# '-'
	.byte	0				# '.'
	.byte	0				# '/'
	.byte	CT_DIGIT|CT_XDIGIT		# '0'
	.byte	CT_DIGIT|CT_XDIGIT		# '1'
	.byte	CT_DIGIT|CT_XDIGIT		# '2'
	.byte	CT_DIGIT|CT_XDIGIT		# '3'
	.byte	CT_DIGIT|CT_XDIGIT		# '4'
	.byte	CT_DIGIT|CT_XDIGIT		# '5'
	.byte	CT_DIGIT|CT_XDIGIT		# '6'
	.byte	CT_DIGIT|CT_XDIGIT		# '7'
	.byte	CT_DIGIT|CT_XDIGIT		# '8'
	.byte	CT_DIGIT|CT_XDIGIT		# '9'
	.byte	0				# ':'
	.byte	0				# ';'
	.byte	0				# '<'
	.byte	0				# '='
	.byte	0				# '>'
	.byte	0				# '?'
	.byte	0				# '@'
	.byte	CT_UPPER|CT_XDIGIT		# 'A'
	.byte	CT_UPPER|CT_XDIGIT		# 'B'
	.byte	CT_UPPER|CT_XDIGIT		# 'C'
	.byte	CT_UPPER|CT_XDIGIT		# 'D'
	.byte	CT_UPPER|CT_XDIGIT		# 'E'
	.byte	CT_UPPER|CT_XDIGIT		# 'F'
	.byte	CT_UPPER			# 'G'
	.byte	CT_UPPER			# 'H'
	.byte	CT_UPPER			# 'I'
	.byte	CT_UPPER			# 'J'
	.byte	CT_UPPER			# 'K'
	.byte	CT_UPPER			# 'L'
	.byte	CT_UPPER			# 'M'
	.byte	CT_UPPER			# 'N'
	.byte	CT_UPPER			# 'O'
	.byte	CT_UPPER			# 'P'
	.byte	CT_UPPER			# 'Q'
	.byte	CT_UPPER			# 'R'
	.byte	CT_UPPER			# 'S'
	.byte	CT_UPPER			# 'T'
	.byte	CT_UPPER			# 'U'
	.byte	CT_UPPER			# 'V'
	.byte	CT_UPPER			# 'W'
	.byte	CT_UPPER			# 'X'
	.byte	CT_UPPER			# 'Y'
	.byte	CT_UPPER			# 'Z'
	.byte	0				# '['
	.byte	0				# '\'
	.byte	0				# ']'
	.byte	0				# '^'
	.byte	0				# '_'
	.byte	0				# '`'
	.byte	CT_LOWER|CT_XDIGIT		# 'a'
	.byte	CT_LOWER|CT_XDIGIT		# 'b'
	.byte	CT_LOWER|CT_XDIGIT		# 'c'
	.byte	CT_LOWER|CT_XDIGIT		# 'd'
	.byte	CT_LOWER|CT_XDIGIT		# 'e'
	.byte	CT_LOWER|CT_XDIGIT		# 'f'
	.byte	CT_LOWER			# 'g'
	.byte	CT_LOWER			# 'h'
	.byte	CT_LOWER			# 'i'
	.byte	CT_LOWER			# 'j'
	.byte	CT_LOWER			# 'k'
	.byte	CT_LOWER			# 'l'
	.byte	CT_LOWER			# 'm'
	.byte	CT_LOWER			# 'n'
	.byte	CT_LOWER			# 'o'
	.byte	CT_LOWER			# 'p'
	.byte	CT_LOWER			# 'q'
	.byte	CT_LOWER			# 'r'
	.byte	CT_LOWER			# 's'
	.byte	CT_LOWER			# 't'
	.byte	CT_LOWER			# 'u'
	.byte	CT_LOWER			# 'v'
	.byte	CT_LOWER			# 'w'
	.byte	CT_LOWER			# 'x'
	.byte	CT_LOWER			# 'y'
	.byte	CT_LOWER 			# 'z'
	.byte	0				# '{'
	.byte	0				# '|'
	.byte	0				# '}'
	.byte	CT_CNTRL			# DEL
