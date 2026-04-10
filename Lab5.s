@ CS309 Lab 5 - Gasoline Pump Simulator
@ Author: Aaron
@ Email: amd0047@uah.edu
@ Date: April 2026
@ Purpose: Simulate gasoline pump. Uses stack for register preservation.
@          Fixed input handling so it no longer hangs on invalid dollar amounts (letters).

@ Assemble:   as -o Lab5.o Lab5.s
@ Link:       gcc -o Lab5 Lab5.o
@ Run:        ./Lab5

.section .data

welcome:        .asciz "Welcome to gasoline pump.\n"
inventory_msg:  .asciz "Current inventory of gasoline (in tenths of gallons) is:\n"
reg_label:      .asciz "Regular     "
mid_label:      .asciz "Mid-Grade   "
prem_label:     .asciz "Premium     "
dollars_msg:    .asciz "Dollar amount dispensed by grade:\n"
reg_dol:        .asciz "Regular $"
mid_dol:        .asciz "Mid-Grade $"
prem_dol:       .asciz "Premium $"
select_prompt:  .asciz "\nSelect Grade of gas to dispense (R, M or P): "
selected_reg:   .asciz "You selected Regular.\n"
selected_mid:   .asciz "You selected Mid-Grade.\n"
selected_prem:  .asciz "You selected Premium.\n"
dollar_prompt:  .asciz "Enter Dollar amount to dispense (At least 1 and no more than 50): "
invalid_grade:  .asciz "Invalid grade selection. Please enter R, M, or P.\n"
invalid_dollar: .asciz "Invalid dollar amount. Must be integer between 1 and 50.\n"
insufficient:   .asciz "Insufficient inventory for this request. Please enter a lower amount.\n"
dispensed:      .asciz " tenths of gallons have been dispensed.\n"
insuf_grade:    .asciz "Insufficient inventory for this grade. Please select another grade.\n"
final_inv:      .asciz "\nFinal inventory levels:\n"
final_dol:      .asciz "Final dollar amounts dispensed:\n"
newline:        .asciz "\n"

grade_buf:      .space 8
dollar_buf:     .space 16
char_buf:       .space 4               @ For single char clear

char_format:    .asciz "%s"
int_format:     .asciz "%d"
single_char:    .asciz "%c"

.align 4
inv_reg:        .word 500
inv_mid:        .word 500
inv_prem:       .word 500

dol_reg:        .word 0
dol_mid:        .word 0
dol_prem:       .word 0

.section .text
.global main
.extern printf
.extern scanf

main:
    push {r4-r11, lr}

    ldr r0, =welcome
    bl  printf

    bl  print_inventory
    bl  print_dollars

main_loop:
    @ Check shutdown condition
    ldr r0, =inv_reg
    ldr r1, [r0]
    cmp r1, #10
    bge get_grade
    ldr r0, =inv_mid
    ldr r1, [r0]
    cmp r1, #10
    bge get_grade
    ldr r0, =inv_prem
    ldr r1, [r0]
    cmp r1, #10
    bge get_grade

    b   shutdown

get_grade:
    ldr r0, =select_prompt
    bl  printf

    ldr r0, =char_format
    ldr r1, =grade_buf
    bl  scanf

    ldr r0, =grade_buf
    ldrb r1, [r0]
    cmp r1, #'S'
    beq show_status
    cmp r1, #'s'
    beq show_status

    cmp r1, #'R'
    beq sel_reg
    cmp r1, #'r'
    beq sel_reg
    cmp r1, #'M'
    beq sel_mid
    cmp r1, #'m'
    beq sel_mid
    cmp r1, #'P'
    beq sel_prem
    cmp r1, #'p'
    beq sel_prem

    ldr r0, =invalid_grade
    bl  printf
    b   main_loop

sel_reg:
    ldr r0, =selected_reg
    bl  printf
    mov r4, #0
    b   ask_dollar

sel_mid:
    ldr r0, =selected_mid
    bl  printf
    mov r4, #1
    b   ask_dollar

sel_prem:
    ldr r0, =selected_prem
    bl  printf
    mov r4, #2
    b   ask_dollar

ask_dollar:
    mov r5, r4                     @ r5 = grade

    bl  has_enough_for_grade
    cmp r0, #0
    beq grade_insufficient

    ldr r0, =dollar_prompt
    bl  printf

    ldr r0, =int_format
    ldr r1, =dollar_buf
    bl  scanf

    cmp r0, #1
    bne dollar_failed

    ldr r6, =dollar_buf
    ldr r6, [r6]

    cmp r6, #1
    blt dollar_failed
    cmp r6, #50
    bgt dollar_failed

    bl  calculate_tenths
    mov r7, r0                     @ requested tenths

    bl  get_inventory
    cmp r0, r7
    blt fuel_insufficient

    bl  subtract_from_inventory
    bl  add_to_dollars

    mov r1, r7
    ldr r0, =int_format
    bl  printf
    ldr r0, =dispensed
    bl  printf

    b   main_loop

dollar_failed:
    ldr r0, =invalid_dollar
    bl  printf
    bl  clear_input_buffer         @ Safe clear - this was the hang source
    b   ask_dollar

fuel_insufficient:
    ldr r0, =insufficient
    bl  printf
    b   ask_dollar

grade_insufficient:
    ldr r0, =insuf_grade
    bl  printf
    b   main_loop

show_status:
    bl  print_inventory
    bl  print_dollars
    b   main_loop

shutdown:
    ldr r0, =final_inv
    bl  printf
    bl  print_inventory

    ldr r0, =final_dol
    bl  printf
    bl  print_dollars

    ldr r0, =newline
    bl  printf

    pop {r4-r11, pc}

@ ====================== Helpers ======================

print_inventory:
    push {lr}
    ldr r0, =inventory_msg
    bl  printf
    ldr r0, =reg_label
    bl  printf
    ldr r0, =inv_reg
    ldr r1, [r0]
    bl  print_num
    ldr r0, =mid_label
    bl  printf
    ldr r0, =inv_mid
    ldr r1, [r0]
    bl  print_num
    ldr r0, =prem_label
    bl  printf
    ldr r0, =inv_prem
    ldr r1, [r0]
    bl  print_num
    pop {pc}

print_dollars:
    push {lr}
    ldr r0, =dollars_msg
    bl  printf
    ldr r0, =reg_dol
    bl  printf
    ldr r0, =dol_reg
    ldr r1, [r0]
    bl  print_num
    ldr r0, =mid_dol
    bl  printf
    ldr r0, =dol_mid
    ldr r1, [r0]
    bl  print_num
    ldr r0, =prem_dol
    bl  printf
    ldr r0, =dol_prem
    ldr r1, [r0]
    bl  print_num
    pop {pc}

print_num:
    push {lr}
    ldr r0, =int_format
    bl  printf
    ldr r0, =newline
    bl  printf
    pop {pc}

calculate_tenths:
    cmp r5, #0
    moveq r0, r6, lsl #2
    bxeq lr
    cmp r5, #1
    moveq r0, #3
    muleq r0, r6, r0
    bxeq lr
    mov r0, r6, lsl #1
    bx lr

has_enough_for_grade:
    bl  get_inventory
    cmp r0, #10
    movge r0, #1
    movlt r0, #0
    bx lr

get_inventory:
    cmp r5, #0
    ldreq r0, =inv_reg
    ldreq r0, [r0]
    cmp r5, #1
    ldreq r0, =inv_mid
    ldreq r0, [r0]
    cmp r5, #2
    ldreq r0, =inv_prem
    ldreq r0, [r0]
    bx lr

subtract_from_inventory:
    cmp r5, #0
    ldreq r0, =inv_reg
    beq do_sub
    cmp r5, #1
    ldreq r0, =inv_mid
    beq do_sub
    ldr r0, =inv_prem
do_sub:
    ldr r1, [r0]
    sub r1, r1, r7
    str r1, [r0]
    bx lr

add_to_dollars:
    cmp r5, #0
    ldreq r0, =dol_reg
    beq do_add
    cmp r5, #1
    ldreq r0, =dol_mid
    beq do_add
    ldr r0, =dol_prem
do_add:
    ldr r1, [r0]
    add r1, r1, r6
    str r1, [r0]
    bx lr

clear_input_buffer:
    push {r4, lr}
clear_loop:
    ldr r0, =single_char
    ldr r1, =char_buf
    bl  scanf
    cmp r0, #1
    bne clear_done
    ldr r2, =char_buf
    ldrb r2, [r2]
    cmp r2, #'\n'
    beq clear_done
    b   clear_loop
clear_done:
    pop {r4, pc}

@ End of program