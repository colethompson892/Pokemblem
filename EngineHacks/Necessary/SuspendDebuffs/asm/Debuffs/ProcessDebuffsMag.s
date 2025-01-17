@Originally at 188A8
.thumb
.macro blh to, reg=r3
  ldr \reg, =\to
  mov lr, \reg
  .short 0xf800
.endm
.equ ProcessBuffs, GetUnitDebuffs+4
.equ ProcessStatusEffects, ProcessBuffs+4 
@This should do what the code in place did
cmp     r0,#0x0
beq     noBarrier
lsr     r1,r2,#0x4
sub     r1,#0x1
lsl     r0,r1,#0x4
noBarrier:
mov     r1,#0xF
mov r9, r1
and     r1,r2
cmp r1, #0x0
beq noTorch
sub r1, #0x1
mov r2, #0x1
mov r8, r2
noTorch: 
orr r0, r1
mov r3, r4
add     r3,#0x31
strb r0, [r3]

@Now the debuffs
ldr r3, GetUnitDebuffs
mov r0,r4
bl BXR3
mov r3,r0
@ ldr r3, debuffTable
@ ldrb r2, [r4, #0xB] @Deployment number
@ lsl r2, #0x3
@ add r3, r2
ldr r2, [r3]
mov r0, #0x0

push {r4}
mov r4, #0x0    @r4 = acc
@0-2: Debuffs, 4 bits each (str/skl/spd/def/res/luk)
@3: Rallys (bit 7 = rally move, bit 8 = rally spectrum)
processDebuffLoop:
mov r1, #0xF    @One stat's debuff
lsl r1, r0
and r1, r2
cmp r1, #0x0
beq noDebuff
lsr r1, r0
sub r1, #0x1    @decrement if there
cmp r1, #0 
beq DoneDecrementing 
sub r1, #1 
cmp r1, #0 
beq DoneDecrementing 
sub r1, #1 @ decrement by 3 each turn 

DoneDecrementing: 

lsl r1, r0
orr r4, r1
noDebuff: 
add r0, #0x4    @next nibble
cmp r0, #0x14
ble processDebuffLoop
str r4, [r3]    @Store processed debuffs/no rallies
pop {r4}
    
@4: Str/Skl Silver Debuff (6 bits), bit 7 = half strength, HO bit = Hexing Rod
ldrb r0, [r3, #0x4]
mov r1, #0x3F       @lower 6 bits
and r1, r0
cmp r1, #0x0
beq noSilverDebuff
sub r1, #0x1
mov r2, #0xC0       @higher 2 bits
and r0, r2          @preserve
orr r0, r1          @Set the new debuff
strb r0, [r3, #0x4] @Store back
noSilverDebuff:

@5: (RallyMag<<4)||MagDebuff
ldrb r0, [ r3, #0x05 ]
mov r1, #0xF
and r0, r1 @ Clear rally mag flag
cmp r0, #0x00
beq NoMagDebuff
	sub r0, r0, #0x01
	cmp r0, #0 
	beq NoMagDebuff 
	sub r0, #1 @ restore by 3 each turn 
	cmp r0, #0 
	beq NoMagDebuff 
	sub r0, #1 
NoMagDebuff:
strb r0, [ r3, #0x05 ]

ldr r3, ProcessBuffs 
mov r0, r4 @ Unit 
bl BXR3

ldr r3, ProcessStatusEffects
mov r0, r4 @ Unit 
bl BXR3

@no need to do anything
ldr r3, ReturnLocation
BXR3:
bx r3

.align
ReturnLocation:
    .long 0x80188E1
GetUnitDebuffs:
    @Handled by installer
