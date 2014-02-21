@*****************************************************************************************
@*****************************************************************************************
@J.S. PEIRCE
@ECE372 - WINTER 2014
@20 FEBRUARY 2014
@BEAGLEBONE BLACK - TEST PROG 3
@TRIGGER GPIO1_14 INTERRUPT, (is pin<16> on BBB), RESPOND BY LIGHTING LED FOR 1 SECOND
@ON GPIO1_12, (which very conveniently happens to BE pin <12> on BBB as well)
@*****************************************************************************************
.text
.global _start
_start:
@*****************************************************************************************
@	IRQ REFERENCE IN TI TRM, SPRUH73J.PDF SECT 6.2, INTERRUPTS BASIC PROG MODEL
@
@	These are all of the registers need to handle interrupts on the MPU side
@*****************************************************************************************
	.equ ACTIVEIRQ_MASK, 0x4		@0x7F is entire space, testing GPIO1_14
	.equ NEWIRQAGR_MASK, 0x1		@WRITE TO INTC_CONTROL AFTER SERVICING,
	.equ INTCPS, 0x48200000			@interrupt controller base addr
	.equ INTC_CONTROL, 0x48200048		@THIS NEEDS TO HAVE A 1 WRITTEN TO BIT 1
	.equ INTC_SYSCONFIG, 0x48200010		@offsets from page 217 spruh73j.pdf
	.equ INTC_IDLE, 0x48200050		@set idle bit
	.equ INTC_MIR3, 0x482000E4  		@actual interrupt mask
	.equ INTC_MIR_SET3, 0x482000EC		@set mask
	.equ INTC_MIR_CLEAR3, 0x482000E8	@clear mask
	.equ INTC_PENDING_IRQ3, 0x482000F8	@pending IRQ after mask, our conditional
@*****************************************************************************************
@			GPIO INITIALIZATIONS
@	the way interrupt signals are mapped to the MPU from the L4 Interconnect, each
@	of the 128 INT signals are broken into 4 banks. GPIO1A and GPIOB are the two
@	interrupts GPIO is capable of outputting to the MPU.
@	bank0[0:31], bank1[32:63], bank2[64:95], bank3[96:127]={INT sig<98:99>}, GPIO1A,B
@*****************************************************************************************
	@for OUTPUT initializations:
	.equ GPIO_PIN12_ON, 0x1000		@SET GPIO[n]->OUTPUT, inverted =PIN HIGH
	.equ OUTPUTEN, 0x4804c134		@(Base + 0x134) enable outputs
	@for GPIO side of INTERRUPTS:
	.equ GPIO_SYSCONFIG, 0x4804c010		@write 1 to enable clock "AUTOIDLE" bit
	.equ GPIO_RISINGDETECT, 0x4804c148	@detect RISING edge on gpio1_14, trigs <98>
	.equ GPIO_LEVELDETECT1, 0x4804c144	@switch INPUT pin will be active HIGH
	@for INPUT:
	.equ GPIO_EOI, 0x4804c020		@ACKNOWLEDGE interrupt occurred/was serviced
	.equ GPIO_IRQSTATUS_0, 0x4804c02c	@the following two registers modify this register
	.equ GPIO_IRQSTATUS_CLR_0, 0x4804c03c	@simply write own value back to clear INT for svc
	.equ GPIO_IRQSTATUS_SET_0, 0x4804c034	@THIS ENABLES THE IRQ ON PIN<14>
	@for OUTPUT:
	.equ GPIO_SETDATAOUT, 0x4804c194	@(...Base+0x194) SET data out, write 1 to bit
	.equ GPIO_CLEARDATAOUT, 0x4804c190  	@(...base + 0x190) Clear data, write 1 to bit
@*****************************************************************************************
@			START LOADINGREGISTERS
@*****************************************************************************************
	ldr r12,=OUTPUTEN		@Write 0, enable OUTPUT, dflt/reset=1's!
	ldr r3, =GPIO_SETDATAOUT	@Write 1 to output data HIGH on GPIO's, (set)
	ldr r2, =GPIO_CLEARDATAOUT	@Write a 1 to output LOW on GPIO's, (clear)
	ldr r7, =GPIO_IRQSTATUS_CLR_0	@CLEAR interrupt, (handled)
	ldr r8, =GPIO_IRQSTATUS_SET_0	@SET interrupt as enabled
	ldr r11,=GPIO_RISINGDETECT	@Detect that HIGH on pin<14> on the RISING edge
@*****************************************************************************************
@			COPY DFLT IRQ HANDLER, STORE IT
@*****************************************************************************************
	mov r9, #0x80000018		@RAM mapping to IVT entry
	@ldr r9,=IRQ_VECTOR		@physical address for RAM IVT
	ldr r1, [r9]			@r9 is IRQ_VECTOR, load the data from the EA in r9 to r1
@*****************************************************************************************
@			CHAIN INTERRUPT PROC
@*****************************************************************************************
	ldr r4, =0x4030ce38		@IVT ADDR (didnt work under a label so it is naked)
	str r1, BTLDR_IRQ_ADDRESS	@store in case button is NOT pushed upon interrupt
	ldr r10,=INT_DIRECTOR		@load addr of INT_DIRECTOR routine
	str r10, [r4]			@write addr of INT_DIRECTOR to IRQ listing in IVT

	mov r9, #0x4			@INT signal<98> is bit 4, bank 3
	ldr r5,=INTC_MIR_CLEAR3 	@unmask interrupt on pin, signal <98> to the MPU
	str r9, [r5]			@by default all masked, so 0xFFFFFFFF->0xFFFFFFFB

	mov r9, #NEWIRQAGR_MASK		@imm is 0x1, which the others need so, recycling
	ldr r5,=INTC_SYSCONFIG		@automatic clock gating strategy applied
	str r9, [r5]
	ldr r5,=INTC_CONTROL		@write 1 to bit 1 allows new IRQ generation
	str r9, [r5]			@(SHOULD only need AFTER servicing)

	mov r9, #0x3
	ldr r5,=INTC_IDLE		@set autogating to sync with INT activity
	str r9, [r5]

	mvn r5, #GPIO_PIN12_ON		@invert 0x00001000_h --> 0xffffefff_h, store in r5
	str r5, [r12]			@write a 0 to bit 12 in OE register, pin<12>=OUT

	mov r9, #0x10
	ldr r5,=GPIO_SYSCONFIG		@set autoidle bit and idle mode bit to "smart idle"
	str r9, [r5]

	mov r9, #0x4000			@bank1 bit 14->GPIO1_14->GPIO_46->pin 16 on P8 Header
	ldr r10,=GPIO_LEVELDETECT1	@Detect interrupt on pin<14> when it goes HIGH
	str r9, [r11]			@set GPIO1_14 to detect rising edge
	str r9, [r10]			@set level to detect logic HIGH on GPIO1_14
	str r9, [r8]			@Set GPIO status, TRIGGERS INTERRUPT IF RAW PENDING!

@*****************************************************************************************
@			ALLOW IRQ interrupts at CPSR (bit 8, little Endian)
@*****************************************************************************************
	mrs r5, cpsr			@READ
	bic r5, #0x80			@MODIFY
	msr cpsr_c, r5			@WRITE

	b wait				@initializations complete! branch to wait state
INT_DIRECTOR:
	stmfd sp!, {r1-r8, lr}		@save register status
	nop
	ldr r9,=INTC_PENDING_IRQ3	@CHECK TO SEE IF IT WAS OUR INTERRUPT
	and r9, r9, #ACTIVEIRQ_MASK	@ACTIVEIRQ_MASK=0x4, full space is 0x7F
	mov r0, #ACTIVEIRQ_MASK		@CURRENTLY 0x4
	cmp r9, r0			@so if it was OUR switch, this is true
	bl light_LED			@To trigger this line, otherwise...
	ldmfd sp!, {r1-r8, lr}	 	@restore registers, stack ptr
	ldr pc, BTLDR_IRQ_ADDRESS	@load PC with the default IRQ svc routine
wait:
@just do something...and loop
	mov r9, #1
	nop
	add r9, r9, #1
	nop
	sub r9, r9, #1
	b wait
light_LED:
	mov r0, #0x400000		@this immediate value passed in as arg to delay proc
	mov r4, #0x1000			@good ole bit 12...our LED
	ldr r3, =GPIO_SETDATAOUT	@load the SETDATAOUT register into R3
	str r4, [r3]			@write 1 to bit 12 to turn on pin<12> LED
	nop
	bl delay			@LED is lit, jump to delay function
	ldr r2,=GPIO_CLEARDATAOUT
	str r4, [r2] 			@turn off pin <12> LED
	b IRQfinal			@returned from delay, INT serviced, re-enable IRQ
@*****************************************************************************************
@			NOW THAT WE HAVE BLINKED, RESET
@*****************************************************************************************
IRQfinal:
	ldr r11,=GPIO_IRQSTATUS_0	@CLEAR INTERRUPT AT GPIO MODULE LEVEL
	ldr r10, [r11]			@write own value back to clear active INTERRUPTS
	str r10, [r11]			@NOTE THIS CLEARS ALL CURRENT INTERRUPTS

	mov r9, #NEWIRQAGR_MASK		@immediate value NEWIRQAGR_MASK is 0x1
	ldr r5,=INTC_CONTROL		@write a 1 to bit 1 to re-enable IRQ
	str r9, [r5]			@and allow new IRQ generation

	mov r9, #0x0			@ACKNOWLEDGE THAT INTERRUPT OCCURRED/WAS SERVICED
	ldr r5,=GPIO_EOI
	str r9, [r5]

	mrs r5, cpsr			@RE-ENABLE INTERRUPTS AT CPSR SINCE FULLY SERVICED
	bic r5, #0x81			@bit 1 switches to SPV, bit 8 is I, IRQ enable bit
	msr cpsr_c, r5
delay:					@this procedure implements a simple, 1 sec delay
	subs r0, r0, #1			@decrement timer
	cmp r0, #0			@has the timer run out?
	bne delay			@if not, call again
	mov pc, lr			@return
BTLDR_IRQ_ADDRESS: .word		@stash the default IRQ svc handler under this label
.end
@*****************************************************************************************
@			EOF
@*****************************************************************************************

