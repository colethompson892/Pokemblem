.thumb 
.macro blh to, reg=r3
  ldr \reg, =\to
  mov lr, \reg
  .short 0xf800
.endm




.global Reinforce_HpRestore
.type Reinforce_HpRestore, %function 

Reinforce_HpRestore:
push {r4-r5, lr} 

mov r4,r0 @r4 = unit
mov r5,r1 @r5 = heal %
ldr r2, [r4] @ Char pointer 
ldrb r2, [r2, #4] @Char ID 
cmp r2, #0xF0 
blt NoHeal
cmp r2, #0xFA 
bge NoHeal 
ldr r0, =0x202BCF0 @ ChapterData 
ldrb r0, [r0, #0xF] 
cmp r0, #0 
bne NoHeal @ Only heal bushes on Player Phase 



mov r0, #50 @ 50% healing 
add r5, r0 



NoHeal: 
mov r0, r5 @ heal % 

pop {r4-r5}
pop {r1} 
bx r1


.ltorg 
.align 

	.equ CurrentUnit, 0x3004E50	@{U}
	.equ MemorySlot,0x30004B8	@{U}
	.equ EventEngine, 0x800D07C	@{U}
	.equ CheckEventId,0x8083da8	@{U}
	.equ NextRN_100, 0x8000c64 @NextRN_100	@{U}
	.equ pActionStruct, 0x203A958	@{U}
	.equ CurrentUnitFateData, 0x203A958	@{U}
	.equ GetUnitStructFromEventParameter, 0x800bc50
	.equ LoadUnit, 0x8017ac4 

.global Reinforce_SpawnIfFull
.type Reinforce_SpawnIfFull, %function 

Reinforce_SpawnIfFull:
push {r4-r7, lr}
@ given unit struct in r0, and unit group in r1, check if full HP. 

@mov r11, r11 @ [0202D0A7]!

mov r4, r0 @ unit 
mov r6, r1 @ target array 


ldr r5, =ReinforcementUnitsQWER@ Unit group 


ldr r0, =0x8000000 
orr r0, r5 @ just in case we didn't do |IsPointer already 

blh LoadUnit 
mov r5, r0 @ Newly loaded unit 

ldrh r1, [r4, #0x10] @ XX / YY 
strh r1, [r5, #0x10] 
@mov r0, r5 @ New unit in r0 
ldr r1, =MemorySlot 
add r1, #4*0x0A @ XX in sA
add r2, r1, #4 @ YY in sB 
ldr r3, =0xFFFFFFFF @ (-1) as failed value 
str r3, [r1]
str r3, [r2] 
bl FindFreeTile @FindFreeTile(struct Unit *unit, int* xOut, int* yOut)

ldr r3, =MemorySlot 
add r3, #4*0x0A @ sA 
mov r2, #0 
ldsh r0, [r3, r2] @ XX 
add r3, #4 
ldsh r1, [r3, r2] @ YY 
strb r0, [r5, #0x10] @ XX 
strb r1, [r5, #0x11] @ YY 

ldr r3, =0x203A958 @ ActionStruct 
strb r0, [r3, #0x13] @ X 
strb r1, [r3, #0x14] @ Y 

ldr r0, =SummonGFXEvent
mov r1, #1
blh EventEngine


@blh 0x8026688 @SMS_Init

mov r0, #1
strb r0, [r4, #0x13] @ current hp [0202D0A7]?
mov r0, #0
strb r0, [r6, #3] @ hp to restore 

mov r0, #1 @ true 
b ExitReinforce_SpawnIfFull 

False:
mov r0, #0 
ExitReinforce_SpawnIfFull:


pop {r4-r7}
pop {r1} 
bx r1 

.global Reinforce_AddBushToPlayerHpRestorationTargetList
.type Reinforce_AddBushToPlayerHpRestorationTargetList, %function 
Reinforce_AddBushToPlayerHpRestorationTargetList:
push {r4-r7, lr} 


mov r6, #0xEF @ Counter 
Loop: 
add r6, #1 
cmp r6, #0xFA 
bge ExitLoop 
mov r0, r6 
blh GetUnitStructFromEventParameter 
cmp r0, #0 
beq Loop 
mov r5, r0 

@r5 as unit 
ldrb r0, [r5, #0x12] @ Max hp 
ldrb r1, [r5, #0x13] @ Current Hp 
cmp r1, r0 
bge Loop @ If full hp already, do not add to list 

mov r0, r5 
mov r1, #0 @ Start with 0 healing 
bl Reinforce_HpRestore
@ r0 as Amount to heal in percentage 
ldrb r1, [r5, #0x12] @ Max hp 
mul r0, r1
mov r1, #100 
blh 0x080D18FC   @//__divsi3 
mov r3, r0 @ Amount to heal as a number 



mov r0, #0x10 
ldsb r0, [r5, r0] 
mov r1, #0x11 
ldsb r1, [r5, r1] 
mov r2, #0xB 
ldsb r2, [r5, r2]

@r3 is specific amount to heal 
@ r3 as (-1) restores status instead? 
blh 0x804F8BC, r4 @ AddTarget 

b Loop 

ExitLoop: 
ExitReinforce_AddToPlayerHpRestorationTargetList: 


pop {r4-r7}
pop {r1} 
bx r1 
.ltorg 
.align 

.global HookAddBushes 
.type HookAddBushes, %function 
HookAddBushes: 
push {lr} 
ldr r0, =0x202BCF0 
ldrb r0, [r0, #0xF] 
blh 0x8025904 @ MakeTerrainHealTargetList 
ldr r0, =0x202BCF0 
ldrb r0, [r0, #0xF] 
cmp r0, #0 
bne SkipReinforce @ Occur only on player phase 
bl Reinforce_AddBushToPlayerHpRestorationTargetList 
SkipReinforce: 
blh 0x804FD28 @ GetTargetListSize 

pop {r1} 
bx r1 
.ltorg 
.align 


.global HookSpawnUnits
.type HookSpawnUnits, %function 
HookSpawnUnits: 
push {r4-r5, lr} 
mov r4, r0 
mov r0, #2 
ldsb r0, [r4, r0] 
blh 0x8019430 @ GetUnitStruct 
mov r5, r0 


ldr r0, [r5] @ Unit Table 
ldrb r0, [r0, #4] @ Unit ID 
cmp r0, #0xF0 
blt ExitSpawnUnits 
cmp r0, #0xFA 
bge ExitSpawnUnits 

ldrb r0, [r5, #0x12] @ max Hp 
ldrb r1, [r5, #0x13] @ current hp 
ldrb r2, [r4, #3]
cmp r2, #0xFF 
beq Error 
add r1, r2 

cmp r0, r1 
bgt Error 

mov r0, r5 
mov r1, r4 
bl Reinforce_SpawnIfFull



Error:
ExitSpawnUnits:
mov r1, r5 
mov r0, #3 

pop {r4-r5} 
pop {r3} 
bx r3

.ltorg 
.align 













