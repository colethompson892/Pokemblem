.thumb 
.macro blh to, reg=r3
  ldr \reg, =\to
  mov lr, \reg
  .short 0xf800
.endm

	.equ pr6C_NewBlocking,           0x08002CE0 
	.equ pr6C_New,                   0x08002C7C
	.equ Proc_CreateBlockingChild, 0x80031c4 
	.equ BreakProcLoop, 0x08002E94
	.equ ProcFind, 0x08002E9C
	.equ EnsureCameraOntoPosition, 0x08015e0d
	.equ CheckEventId, 0x8083da8
	.equ MemorySlot, 0x30004B8
	.equ CurrentUnit, 0x3004E50
	.equ EventEngine, 0x800D07C
	

.global ASMC_Draw
.type ASMC_Draw, %function 

ASMC_Draw:
push {r4-r5, lr} 
mov r4, r0 
mov r1, r4 @ Parent proc 
ldr r0, =DrawSpriteProc
@ arguments: r0 = pointer to ROM 6C code, r1 = parent; returns: r0 = new 6C pointer (0 if no space available)
blh pr6C_NewBlocking
@mov r1, #3 
@blh pr6C_New


pop {r4-r5}
pop {r0} 
bx r0 

.align 4
.global Draw_SetupMemorySlots
.type Draw_SetupMemorySlots, %function 

@ This function is only used for battles. The ASMC / AoE version does not use this. 
Draw_SetupMemorySlots:
push {lr}


@ldr r3, =0x203a608 @gpCurrentRound
@ldr r0, [r3] 
@ldr r1, [r0] 
@mov r11, r11 

@bl Draw_GetActiveCoords
@mov r11, r11 


bl Draw_GetAnimationIDByWeapon @ Takes no params, returns animation id to use 
ldr r3, =MemorySlot 
str r0, [r3, #4] @ slot 1 - animation ID 


blh GetGameClock 
ldr r3, =MemorySlot
str r0, [r3, #4*3] @ slot 3



@ copied from function 080815C0 //MapAnim_MoveCameraOnTarget MapAnim_MoveCameraOnTarget
ldr r3, =0x203E1F0 @(gMapAnimStruct )
mov r1, r3 
add r1, #0x59 
ldrb r2, [r1]
lsl r1, r2, #2 
add r1, r2 
lsl r1, #2 
add r1, r3 
ldr r2, [r1] 
mov r1, #0x10 
ldsb r0, [r2, r1] @ XX 
ldrb r1, [r2, #0x11] @ YY 
lsl r1, #24 
asr r1, #24 
@ bl EnsureCameraOntoPosition - this is what the function usually does 


ldr r3, =MemorySlot 
add r3, #4*0x0B 

@ldr r2, =CurrentUnit 
@ldrb r0, [r2, #0x10] 
@ldrb r1, [r2, #0x11] 

strh r0, [r3] 
strh r1, [r3, #2] 

pop {r1}
bx r1 

	.equ BreakProcLoop, 0x08002E94
.align 
.ltorg

.equ RegisterTileGraphics, 0x8002014 
.equ RegisterObjectTileGraphics, 0x8012FF4 

.global Draw_StoreToBuffer
.type Draw_StoreToBuffer, %function 
Draw_StoreToBuffer:
push {r4-r7, lr}
ldr r4, =0x6010000 @ tile one 
ldr r5, =0x6010FFF @ end of first two rows 


blh 0x8001FE0 @| ClearTileRigistry

blh GetGameClock 
ldr r3, =MemorySlot
str r0, [r3, #4*3] @ slot 3


ldr r3, =MemorySlot 
ldr r3, [r3, #4] @ Slot 1 
lsl r3, #2 @ x4 
add r0, r3, r3 @ x8 
add r0, r3 @ x12 
add r0, #4 @ palette offset in table 
ldr r2, =AnimTable 

ldr r0, [r2, r0] @ Palette 
cmp r0, #0 
beq SkipUpdatingPalette @ No animation 

UpdatePalette:
mov r1, #26 @ palette # 
lsl r1, #5 @ multiply by #0x20



mov	r2,#0x20
blh CopyToPaletteBuffer @Arguments: r0 = source pointer, r1 = destination offset, r2 = size (0x20 per full palette)

@ palette must be updated 
ldr	r0,=#0x300000E @ 0300000E is a byte (bool) that tells the game whether the palette RAM needs to be updated
mov	r1,#1
strb r1,[r0]

SkipUpdatingPalette:

mov r0, #0 
ldr r3, =MemorySlot 
add r3, #4*0x0B 
ldrh r1, [r3] @ XX 
ldrh r2, [r3, #2] @ YY 
blh EnsureCameraOntoPosition




pop {r4-r7}
pop {r1}
bx r1 

.align 4 
.ltorg 

.equ CopyToPaletteBuffer, 0x8000DB8
.equ PushToSecondaryOAM, 0x08002BB8
.equ GetGameClock, 0x08000D28






.global Draw_WaitXFrames
.type Draw_WaitXFrames, %function 
Draw_WaitXFrames:
push {r4, lr}

mov r4, r0 @ Parent? 
blh GetGameClock 

ldr r3, =MemorySlot
ldr r2, [r3, #12] @ initial game clock time in s3
sub r0, r2 @ Number of frames since then 

ldr r2, =MinimumFramesLink
ldr r2, [r2] 
cmp r0, r2 
ble End_DrawPause @ regardless of animation or not, always pause at least X frames 


@ Get total frames now 
ldr r3, =MemorySlot 
ldr r3, [r3, #4] @ Slot 1 
lsl r3, #2 @ x4 
add r2, r3, r3 @ x8 
add r2, r3 @ x12 
ldr r3, =AnimTable 
ldr r3, [r3, r2] @ Specific animation table 
cmp r3, #0 
beq NoAnimation

sub r3, #8
mov r2, #0 @ Number of frames to wait 

NumberOfFramesLoop:
add r3, #8 
ldrh r1, [r3] 
add r2, r1 @ total frames 
cmp r1, #0 
bne NumberOfFramesLoop


cmp r0, r2
bge BreakProcLoopNow
mov r0, #0 
b End_DrawPause

NoAnimation:
VanillaHP_BarRoutine:
mov r0, r4 @ parent proc 
blh 0x8081914 @ default routine wait for hp to finish going down 
b End_DrawPause

BreakProcLoopNow:
mov r0, r4 @  @ parent to break from 
blh 0x8081914 @ default routine wait for hp to finish going down 
@blh BreakProcLoop
mov r0, #1
End_DrawPause:

pop {r4}
pop {r1}
bx r1 


.type Draw_GetActiveCoords, %function  
Draw_GetActiveCoords:
push {lr}

ldr r3, =0x203E1F0 @(gMapAnimStruct )
mov r1, r3 
add r1, #0x59 
ldrb r2, [r1]
lsl r1, r2, #2 
add r1, r2 
lsl r1, #2 
add r1, r3 
ldr r2, [r1] 
mov r1, #0x10 
ldsb r0, [r2, r1] @ XX 
ldrb r1, [r2, #0x11] @ YY 
lsl r1, #24 
asr r1, #24 


pop {r2}
bx r2 
.align 4 

.global Draw_GetActiveAttackerOrDefender
.type Draw_GetActiveAttackerOrDefender, %function 
Draw_GetActiveAttackerOrDefender:
push {r4, lr} 

bl Draw_GetActiveCoords @ I guess this returns the target's coords? 


ldr r3, =0x203A4EC @ Atkr 
ldr r4, =0x203A56C @ Dfdr 
ldrb r2, [r3, #0x10]
cmp r2, r0
bne TryDfdr
ldrb r2, [r3, #0x11] 
cmp r2, r1 
bne TryDfdr 
b ExitDraw_GetActiveAttackerOrDefender


TryDfdr:
ldr r3, =0x203A56C @ Dfdr 
ldr r4, =0x203A4EC @ Atkr 
ldrb r2, [r3, #0x10]
cmp r2, r0  
bne RetFalse
ldrb r2, [r3, #0x11] 
cmp r2, r1 
bne RetFalse 
b ExitDraw_GetActiveAttackerOrDefender


RetFalse:
mov r3, #0
mov r4, #0  
ExitDraw_GetActiveAttackerOrDefender:
mov r1, r3 @ Target @ we found the target's coords, so let's instead use the active unit 
mov r0, r4 @ Active 

@ r0 has the atkr or dfdr struct 

pop {r4} 
pop {r2}
bx r2


.global Draw_GetAnimationIDByWeapon
.type Draw_GetAnimationIDByWeapon, %function 
Draw_GetAnimationIDByWeapon:
push {r4, lr}


bl Draw_GetActiveAttackerOrDefender 

cmp r0, #0 
beq Error 
mov r4, r0 

@ Current unit's battle struct is in r4 
mov r0, r4
add r0, #0x4A @ Active unit's weapon 
ldrb r0, [r0] @ Weapon ID 

mov r2, #0 @ Counter 
ldr r3, =SpecificWeaponAnimations
sub r3, #2 @ 2 bytes per 
AnimationBySpecificWeapon_Loop:
add r3, #2 
ldr r1, [r3] 
cmp r1, #0 
beq BreakAnimationBySpecificWeapon_Loop
ldrb r1, [r3] 
cmp r0, r1 
bne AnimationBySpecificWeapon_Loop
ldrb r0, [r3, #1] @ Animation ID 
b ExitDraw_GetAnimationIDByWeapon @ We found an animation for that specific weapon 

BreakAnimationBySpecificWeapon_Loop:
blh 0x8017548 @GetItemWType

mov r2, #0 @ Counter 
ldr r3, =WeaponTypeAnimations
sub r3, #2 

AnimationByWeaponType_Loop:
add r3, #2 
ldr r1, [r3] 
cmp r1, #0 
beq Error @ No animation found for this weapon type, so error 
ldrb r1, [r3] 
cmp r0, r1 
bne AnimationByWeaponType_Loop
ldrb r0, [r3, #1] @ Animation ID 
b ExitDraw_GetAnimationIDByWeapon

Error:
mov r0, #0 @ 0th animation is none 


ExitDraw_GetAnimationIDByWeapon:

pop {r4}
pop {r1}
bx r1 
.align 


.global Draw_PushToOam
.type Draw_PushToOam, %function 
Draw_PushToOam:
push {r4-r7, lr}

mov r5, r0 

push {r5} 

@ get coordinates 
ldr r3, =MemorySlot 
add r3, #4*0x0B 
ldrh r5, [r3]
ldrh r6, [r3, #2]



ldr r3, =0x202BCBC @(gCurrentRealCameraPos )
ldrh r0, [r3]
ldrh r1, [r3, #2] 

lsr r0, #4 @ fsr cam pos gives coords <<#4 bits over 
lsr r1, #4 
sub r5, r0 
sub r6, r1 

@ r0 = XX, r1 = YY
lsl r0, r5, #4 @ 16*XX 
lsl r1, r6, #4 @ 16*YY 
bl Draw_NumberDuringBattle

sub r5, #1 @ offset by 1 to center 64x64 animations 
sub r6, #1 


blh GetGameClock 


ldr r3, =MemorySlot
ldr r2, [r3, #12] @ initial game clock time in s3
sub r0, r2 @ frame we're on



 
ldr r3, =MemorySlot 
ldr r3, [r3, #4] @ Slot 1 
lsl r3, #2 @ x4 
add r2, r3, r3 @ x8 
add r2, r3 @ x12 
ldr r3, =AnimTable 
ldr r3, [r3, r2] @ Specific animation table 
cmp r3, #0 @ No animation, so exit 
beq ExitAnimation
sub r3, #8 
mov r1, #0 @ frames offset 
b TryNextFrameLoop 
ExitAnimation: 
@7b878 sets to 0 
@ 81698, 7bd3a 
@ldr r3, =0x203E24F @(gMapAnimaionWait )
@mov r0, #1
@strb r0, [r3] 


b Skip

TryNextFrameLoop:
add r3, #8 
ldrh r2, [r3] 
add r1, r2 
cmp r2, #0 
beq ExitAnimation
cmp r0, r1 
bge TryNextFrameLoop 



ldr r0, [r3, #4] 

ldr r1, =VRAM_Address_Link
ldr r1, [r1] 
ldr r2, =#4096 @ number of bytes 
mov r2, #8
mov r3, #8
@ Arguments: r0 = Source gfx (uncompressed), r1 = Target pointer, r2 = Tile Width, r3 = Tile Height
blh RegisterObjectTileGraphics, r4



sub sp, #8 


@ Prepare OAM data
mov   r2, #0x1
mov   r1, sp
str   r2, [r1]
mov   r2, #0x0
str   r2, [r1, #0x4]


@	bit 0-9   | Tile Number     (0-1023)
@			bit 10    | Horizontal Flip (0=Normal, 1=Mirrored)
@			bit 11    | Vertical Flip   (0=Normal, 1=Mirrored)
@			bit 12-15 | Palette Number  (0-15)





@ Clear number data buffer 
@ldr r3, =0x2028e44 @gDebugNumberString
@mov r2, #0 
@str r2, [r3] 
@add r3, #4 
@str r2, [r3] 
@add r3, #4 
@str r2, [r3] @ Cleared 



ldr r7, =VRAM_Address_Link
ldr r7, [r7] 
lsr r7, #5 @ eg. tile #0x198 - offset where we put the tiles 

@ Push to secondary OAM
@To compute the offset for one tile in the map buffer given its (x, y) pos: offset = 2*x + 0x40*y
lsl r0, r5, #4 @ 16*XX 


@	00 | short | base OAM0 data (y coord, various flags, shape)
@			02 | short | base OAM1 data (x coord, flips, size)
@			04 | short | base OAM2 data (tile index, priority, palette index)
mov   r2, #0xc0 @ #0xC0 64x64  FF 
lsl   r2, #0x8 @ shifted by this amount 
orr   r0, r2                    @ Sprite size, 32x32


lsl r1, r6, #4 @ 16*YY 
sub r1, #8 
sub r0, #8 



mov r3, r7
mov r2, #26 @ palette # 26 - or 27 is the light rune palette i think 
lsl r2, #12 @ bits 12-15 
add r3, r2 @ palette | flips | tile 

mov r2, sp 

@ r0 = base x coord, r1 = base y coord, r2 = pointer to OAM Data, r3 = base OAM2 (tile/palette index)
blh PushToSecondaryOAM, r4 

add sp, #8 

Skip:
pop {r5} 

mov r0, r5 
bl Draw_WaitXFrames

pop {r4-r7}
pop {r1}
bx r1 















.align 4

.global Draw_NumberDuringBattle
.type Draw_NumberDuringBattle, %function 


Draw_NumberDuringBattle:
push {r4-r7, lr}

mov r4, r0 @ XX 
mov r5, r1 @ YY 


blh GetGameClock 
ldr r3, =MemorySlot
ldr r2, [r3, #4*3] @ slot 3
sub r0, r2 @ Number of frames since animation started 
mov r6, r0 
lsr r6, #1 @ every 2 frames move upwards 
cmp r6, #13 
blt Continue_DrawNumber
mov r6, #13 @ max height is +16 above 
Continue_DrawNumber:
sub r5, r6 

lsr r0, r6, #1 
add r0, #5 
DivisionLoop:
sub r0, #5 
cmp r0, #5 
bgt DivisionLoop 

add r4, #5 
sub r4, r0 @ subtract or add based on the remainder so that it will wiggle ? 








@bl Draw_GetActiveAttackerOrDefender
@cmp r0, #0 
@beq ExitDraw_NumberDuringBattle
@ldr r1, =0x203A4EC @ Atkr 
@
@@DetermineBattleActorSide:
@ldr r2, =0x203E108 @ what side is the battle actor on? 
@ldrb r2, [r2] 
@cmp r2, #1 
@bne DontSwapSides
@ldr r1, =0x203A56C @ Dfdr 
@DontSwapSides:
@
@cmp r0, r1 
@bne BattleSideRight 
@
@DeducedAtkrOrDfdr: 
@mov r2, r0 @ Active unit 
@mov r3, r1 @ Target
@
@BattleSideLeft:
@mov r0, #0 
@ldr r3, =0x0203E1BC @ Battle side 1 - See febuilder debugger "BattleSome" struct starting at 0203E0F0
@ldsh r0, [r3, r0] 
@cmp r0, #0 
@blt ExitDraw_NumberDuringBattle
@b FoundDamage
@
@BattleSideRight:
@mov r0, #0 
@ldr r3, =0x203E1BE @ Battle side 2
@ldsh r0, [r3, r0] 
@cmp r0, #0 
@blt ExitDraw_NumberDuringBattle

@FoundDamage:


ldr r3, =0x203E24A @ current round - from function 8161C - address 81676 
ldrh r1, [r3] 
mov r2, #2 
and r1, r2 
cmp r1, #0 
bne ExitDraw_NumberDuringBattle
ldrb r0, [r3, #3] @ dmg? 





mov r7, r0 @ Damage to deal 

@mov r7, #64


mov r1, r7 
cmp r7, #10 
blt SkipTensDigit

add r1, #10 
mov r2, #0 @ counter
sub r2, #1 

 
GetRemainderLoop:
sub r1, #10 
add r2, #1 
cmp r1, #10 
bge GetRemainderLoop 
@r2 as Top digit only 
mov r7, r1 @ remainder only 



mov r0, r4 
mov r1, r5 


bl Draw_NumberOAM

SkipTensDigit:
mov r0, r4 
mov r1, r5 
add r0, #8 
mov r2, r7 
bl Draw_NumberOAM


	@ Inputs:
	@ r0: X coordinate
	@ r1: Y coordinate
	@ r2: Number
@mov r2, #64 

mov r2, r7 
@blh MMBDrawUnsignedNumber

ExitDraw_NumberDuringBattle:

pop {r4-r7}
pop {r1}
bx r1 

.equ SpriteData8x8,			0x08590F44

Draw_NumberOAM:
@ referenced Zane's MMB function for this 
.type	Draw_NumberOAM, %function

@ Inputs:
@ r0: X coordinate
@ r1: Y coordinate
@ r2: Number

push	{lr}

@ We'll need all scratch registers,
@ so we set lr first

ldr		r3, =PushToSecondaryOAM 
mov		lr, r3

@ add number to base
@ 0-9 in r2 is the number
@ 0x0A in r2 is a dash
ldr		r3, =0x81C0 @ Number base tile
cmp r2, #5 
ble GotOffset
ldr		r3, =0x81E0 @ Number base tile
sub r2, #6  
GotOffset:
add		r3, r2, r3

@ OAM data for a single 8x8 sprite

ldr		r2, =SpriteData8x8

.short 0xf800 

pop		{r0}
bx		r0




.global Draw_Cleanup
.type Draw_Cleanup, %function 

Draw_Cleanup:
push {r4-r7, lr}
blh 0x8021668 @ Redraw map at end of event effect 


@ palette must be updated 
ldr	r0,=#0x300000E @ 0300000E is a byte (bool) that tells the game whether the palette RAM needs to be updated
mov	r1,#0
strb r1,[r0]


mov r0, #0 
ldr r1, =VRAM_Address_Link
ldr r1, [r1] 
ldr r2, =#4096 @ 64x64 image bytes size 
@=#4096 @64x64 image bytes 
@Arguments: r0 = *word* to fill with, r1 = Destination pointer, r2 = size (bytes)
blh 0x08002054 @ RegisterFillTile

blh 0x8001FE0 @| ClearTileRigistry


pop {r4-r7}
pop {r1}
bx r1 





