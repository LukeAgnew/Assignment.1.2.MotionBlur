	AREA	MotionBlur, CODE, READONLY
	IMPORT	main
	IMPORT	getPicAddr
	IMPORT	putPic
	IMPORT	getPicWidth
	IMPORT	getPicHeight
	EXPORT	start
	PRESERVE8

start

	BL	getPicAddr					; load the start address of the image in R4
	MOV	R4, R0
	BL	getPicHeight				; load the height of the image (rows) in R5
	MOV	R5, R0
	BL	getPicWidth					; load the width of the image (columns) in R6
	MOV	R6, R0
	
	MOV R0,R4						; starting address parameter
	MOV R1,R5						; image height parameter
	MOV R2,R6						; image width parameter
	MOV R3,#11						; radius of effect parameter

	BL motionBlur					; invoke motionBlur(address, height, width, radius)

	BL	putPic						; re-display the updated image

stop	B	stop


; motionBlur subroutine
; Applies a "motion blur" effect to an image by replacing the Red, Green and Blue
; color values of each pixel with the average of the corresponding color channels
; from the pixels in a line through each pixel.
; parameters	R0:	starting address of the image
;				R1:	image height
;				R2:	image width
;				R3:	radius of effect

motionBlur
	STMFD SP!,{R4-R12,lr}			; save registers

	SUB R3,R3,#1					; radius = radius - 1
	STMFD SP!,{R0-R1}				; save address and height to the system stack
	
	MOV R0,R3						; dividend parameter
	MOV R1,#2						; divisor parameter
	
	BL divide						; invoke divide(dividend, divisor)
	MOV R3,R0						; radius = quotient
	
	LDMFD SP!,{R0-R1}				; restore address and height from the system stack
	
	LDR R4,=0
fori								; for (int i=0; i<height; i++)
	CMP R4,R1						; {
	BHS endfori
	
	LDR R5,=0
forj								; for (int j=0; j<width; j++)
	CMP R5,R2						; {
	BHS endforj
	
	MOV R8,#0						; indexOffset = 0
	MOV R9,#0						; redTotal = 0
	MOV R10,#0						; greenTotal = 0
	MOV R11,#0						; blueTotal = 0
	MOV R12,#0						; pixelCount = 0
			
	SUB R7,R5,R3					; channelj = j-radius
	SUB R6,R4,R3					; channeli = i-radius

checkIndices
	CMP R7,#0						; if (channelj < 0)		
	BLT changeIndices				; { offset this index }		
				
	CMP R6,#0						; if (channeli < 0)		
	BLT changeIndices				; { offset this index }	
		
	ADD R8,R4,R3					; channelLimit = i+radius
forChannel							
	CMP R6,R8						; for (channeli; channeli<channelLimit; channeli++)
	BGT endforChannel				; {
	
	CMP R6,R1						; if (channeli < height)
	BGE endforChannel				; {
	
	CMP R7,R2						; if (channelj < width)
	BGE endforChannel				; {
	
computeAverage
	STMFD SP!, {R0-R3}				; save address, height, width and radius to the system stack

	MOV R1,R6						; index i parameter
	MOV R3,R2						; width parameter
	MOV R2,R7						; index j parameter
	
	BL getPixelR					; invoke getPixelR(address, i, j, width)
	ADD R9,R9,R0					; redTotal += red component
	
	LDMFD SP!,{R0-R3}				; restore address, height, width and radius from the system stack
	
	STMFD SP!, {R0-R3}				; save address, height, width and radius to the system stack

	MOV R1,R6						; index i parameter
	MOV R3,R2						; width parameter
	MOV R2,R7						; index j parameter
	
	BL getPixelG					; invoke getPixelG(address, i, j, width)
	ADD R10,R10,R0					; greenTotal += green component
	
	LDMFD SP!,{R0-R3}				; restore address from the system stack
	
	STMFD SP!, {R0-R3}				; save height, width and radius to the system stack

	MOV R1,R6						; index i parameter
	MOV R3,R2						; width parameter
	MOV R2,R7						; index j parameter
	
	BL getPixelB					; invoke getPixelB(address, i, j, width)
	ADD R11,R11,R0					; blueTotal += blue component

	LDMFD SP!,{R0-R3}				; restore height, width and radius from the system stack
	
	ADD R12,R12,#1					; pixelCount++
									; }
endcomputeAverage					; }

	ADD R7,R7,#1					; channelj++
	ADD R6,R6,#1					; channeli++
	
	B forChannel					; }
	
changeIndices
	ADD R8,R8,#1					; indexOffset++

	ADD R7,R5,R8					; channelj = j + indexOffset
	ADD R6,R4,R8					; channeli = i + indexOffset

	SUB R7,R7,R3					; channelj = channelj - radius
	SUB R6,R6,R3					; channeli = channeli - radius

	B checkIndices
endchangeIndices	
endforChannel
	
	STMFD SP!,{R0-R1}				; store address and height to the system stack
	
	MOV R0,R9						; dividend parameter
	MOV R1,R12						; divisor parameter
	
	BL divide						; invoke divide(dividend, divisor)	
	MOV R9,R0						; redAverage = quotient
	
	MOV R0,R10						; dividend parameter
	MOV R1,R12						; divisor parameter
	
	BL divide						; invoke divide(dividend, divisor)	
	MOV R10,R0						; greenAverage = quotient
	
	MOV R0,R11						; dividend parameter
	MOV R1,R12						; divisor parameter
	
	BL divide						; invoke divide(dividend, divisor)	
	MOV R11,R0						; blueAverage = quotient
	
	LDMFD SP!,{R0-R1}				; restore address and height from the system stack
	
	STMFD SP!,{R0-R3}				; store address, height, width and radius to the system stack
	
	MOV R1,R4						; index i parameter
	MOV R3,R2						; width parameter
	MOV R2,R5						; index j parameter
	STR R9, [SP, #-4]!				; value parameter	
	
	BL setPixelR					; invoke setPixelR(address, i, j, width, value)	
	ADD SP,SP,#4					; pop parameter off the stack
			
	MOV R1,R4						; i parameter = i
	STR R10, [SP, #-4]!				; value parameter
	
	BL setPixelG					; invoke setPixelG(address, i, j, width, value)	
	ADD SP,SP,#4					; pop parameter off the stack
		
	MOV R1,R4						; i parameter = i
	STR R11, [SP, #-4]!				; value parameter
	
	BL setPixelB					; invoke setPixelB(address, i, j, width, value)	
	ADD SP,SP,#4					; pop parameter off the stack
	
	LDMFD SP!,{R0-R3}				; restore height, width and radius from the system stack
			
	ADD R5,R5,#1					
	B forj							; }
endforj

	ADD R4,R4,#1
	B fori							; }
endfori

	LDMFD SP!, {R4-R12,pc}			; restore registers
	
	
; divide subroutine
; Takes a number (the dividend) and divides it by another number (the divisor) and
; then returns the result (the quotient)
; parameters   R0: The dividend, i.e. the number to be divided
;			   R1: The divisor, i.e. the number to divide into the dividend
; return value R0: quotient
	
divide
	STMFD sp!, {R4, lr}				; save registers
	MOV R4,#0						; quotient = 0
wh	CMP R0, R1						; while (dividend > divisor)
	BLO endwh						; {
	SUB R0, R0, R1					; dividend = dividend - divisor
	ADD R4,R4,#1					; quotient = quotient + 1
	B wh							; }
endwh
	MOV R0,R4						; return value = quotient
	LDMFD sp!, {R4, pc}			; restore registers


; getPixelR subroutine
; Retrieves the Red color component of a specified pixel
; from a two-dimensional array of pixels.
; parameters	R0: starting address of the array
;				R1: index i of the pixel
;				R2: index j of the pixel
;				R3: width of the array

getPixelR
	STMFD SP!, {R4, lr}				; save registers

	MUL R1,R3,R1					; row * rowSize						
	ADD R1,R1,R2					; row*rowSize + column 
	
	LDR R0, [R0, R1, LSL #2]		; pixel = Memory.Word[address + (index * 4)]
	MOV R0,R0, LSR #16				; redComponent = pixel shifted right by 16 bits
	
	LDMFD SP!, {R4,PC}				; restore registers
	
	
; getPixelG subroutine
; Retrieves the Green color component of a specified pixel
; from a two-dimensional array of pixels.
; parameters	R0: starting address of the array
;				R1: index i of the pixel
;				R2: index j of the pixel
;				R3: width of the array
	
getPixelG
	STMFD SP!, {R4, lr}				; save registers

	MUL R1,R3,R1					; row * rowSize						
	ADD R1,R1,R2					; row*rowSize + column 
	
	LDR R0, [R0, R1, LSL #2]		; pixel = Memory.Word[address + (index * 4)]
	MOV R0,R0,LSR #8 				; greenComponent = pixel shifted right by 8 bits and
	
	LDR R4,=0xFFFFFF00				; combined with a mask to clear the redComponent value
	BIC R0,R0,R4
	
	LDMFD SP!, {R4,PC}				; restore registers
	
	
; getPixelB subroutine
; Retrieves the Blue color component of a specified pixel
; from a two-dimensional array of pixels.
; parameters	R0: starting address of the array
;				R1: index i of the pixel
;				R2: index j of the pixel
;				R3: width of the array
	
getPixelB
	STMFD SP!, {R4, lr}				; save registers

	MUL R1,R3,R1					; row * rowSize						
	ADD R1,R1,R2					; row*rowSize + column 
	
	LDR R0, [R0, R1, LSL #2]		; pixel = Memory.Word[address + (index * 4)]
	LDR R4,=0xFFFFFF00				; blueComponent = pixel combined with a mask to clear
	BIC R0,R0,R4					; the redComponent and greenComponent values
	
	LDMFD SP!, {R4,PC}				; restore registers

; setPixelR subroutine
; Sets the Red color component of a specified pixel in a
; two-dimensional array of pixels.
; parameters	R0:	starting address of the array
;				R1: index i of pixel
;				R2: index j of pixel
;				R3: width of the array
;			   [SP]: value added to the stack
setPixelR
	STMFD SP!, {R4-R5, lr}			; save registers

	MUL R1,R3,R1					; row * rowSize
	ADD R1,R1,R2					; row*rowSize + column
	
	LDR R4,[R0, R1, LSL #2]			; pixel = Memory.Word[address + (index*4)]
	
	BIC R4,R4,#0x00FF0000			; clear the pixel's current redComponent value
	
	LDR R5,[SP, #0 + 12]			; load the redComponent value from the stack	
	MOV R5,R5,LSL #16				; shift redComponent value left by 16 bits

	ADD R4,R4,R5					; add this redComponent value to the pixel
	
	STR R4, [R0, R1, LSL #2]		; Memory.Word[address + (index*4)] = pixel
	
	LDMFD SP!, {R4-R5, pc}			; restore registers
	

; setPixelG subroutine
; Sets the Green color component of a specified pixel in a
; two-dimensional array of pixels.
; parameters	R0:	starting address of the array
;				R1: index i of pixel
;				R2: index j of pixel
;				R3: width of the array
;			   [SP]: value added to the stack
setPixelG
	STMFD SP!, {R4-R5, lr}			; save registers

	MUL R1,R3,R1					; row * rowSize
	ADD R1,R1,R2					; row*rowSize + column
	
	LDR R4,[R0, R1, LSL #2]			; pixel = Memory.Word[address + (index*4)]
	
	BIC R4,R4,#0x0000FF00			; clear the pixel's current greenComponent value
	
	LDR R5,[SP, #0 + 12]			; load the greenComponent value from the stack		
	MOV R5,R5,LSL #8				; shift the greenComponent value left by 8 bits

	ADD R4,R4,R5					; add this greenComponent value to the pixel
	
	STR R4, [R0, R1, LSL #2]		; Memory.Word[address + (index*4)] = pixel
	
	LDMFD SP!, {R4-R5, pc}			; restore registers


; setPixelB subroutine
; Sets the Blue color component of a specified pixel in a
; two-dimensional array of pixels.
; parameters	R0:	starting address of the array
;				R1: index i of pixel
;				R2: index j of pixel
;				R3: width of the array
;			   [SP]: value added to the stack
setPixelB
	STMFD SP!, {R4-R5, lr}			; save registers

	MUL R1,R3,R1					; row * rowSize
	ADD R1,R1,R2					; row*rowSize + column
	
	LDR R4,[R0, R1, LSL #2]			; pixel = Memory.Word[address + (index*4)]
	
	BIC R4,R4,#0x000000FF			; clear the pixel's current blueComponent value
	
	LDR R5,[SP, #0 + 12]			; load the blueComponent value from the system stack
	
	ADD R4,R4,R5					; add this blueComponent value to the pixel
	
	STR R4, [R0, R1, LSL #2]		; Memory.Word[address + (address*4)] = pixel
	
	LDMFD SP!, {R4-R5, pc}			; restore registers
	
	END	