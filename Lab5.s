@ CS309 Lab 5 - Gasoline Pump Simulator
@ Author: Aaron
@ Email: amd0047@uah.edu
@ Date: April 2026
@ Purpose: Simulate a gasoline pump with Regular, Mid-Grade, and Premium.
@          Uses the stack to save/restore registers across loops and calls.
@          Features: input validation, inventory tracking, insufficient fuel checks,
@          hidden status code 'S', and automatic shutdown when all grades < 10 tenths.

@ Assemble:   as -o Lab5.o Lab5.s
@ Link:       gcc -o Lab5 Lab5.o
@ Run:        ./Lab5
@ Debug:      gdb ./Lab5

.section .data

@ === Output Messages ===
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

@ === Input Buffers and Formats ===
grade_buf:      .space 8           @ Buffer for grade input (S, R, M, P)
dollar_buf:     .space 16          @ Buffer for dollar amount
char_format:    .asciz "%s"        @ For reading grade as string
int_format:     .asciz "%d"        @ For reading integer dollars

@ === Data Variables (all integers) ===
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
    push {r4-r11, lr}              @ Save callee-saved registers + lr on stack

    @ Display welcome and initial status
    ldr r0, =welcome
    bl  printf

    bl  print_current_inventory
    bl  print_current_dollars

main_loop:                         @ === Main program loop (clearly documented) ===
    @ Check if all grades are below 10 tenths (1 gallon) - shutdown condition
    ldr r0, =inv_reg
    ldr r1, [r0]
    cmp r1, #10
    bge get_user_grade

    ldr r0, =inv_mid
    ldr r1, [r0]
    cmp r1, #10
    bge get_user_grade

    ldr r0, =inv_prem
    ldr r1, [r0]
    cmp r1, #10
    bge get_user_grade

    b   shutdown                   @ All grades insufficient → end program

get_user_grade:
    ldr r0, =select_prompt
    bl  printf

    @ Read grade input
    ldr r0, =char_format
    ldr r1, =grade_buf
    bl  scanf

    @ === Hidden Secret Code Check (S or s) ===
    ldr r0, =grade_buf
    ldrb r1, [r0]                  @ Load first character entered
    cmp r1, #'S'
    beq show_status
    cmp r1, #'s'
    beq show_status

    @ Check for valid grades (R/r, M/m, P/p)
    cmp r1, #'R'
    beq select_reg
    cmp r1, #'r'
    beq select_reg

    cmp r1, #'M'
    beq select_mid
    cmp r1, #'m'
    beq select_mid

    cmp r1, #'P'
    beq select_prem
    cmp r1, #'p'
    beq select_prem

    @ Invalid grade error handling
    ldr r0, =invalid_grade
    bl  printf
    b   main_loop

select_reg:
    ldr r0, =selected_reg
    bl  printf
    mov r4, #0                     @ 0 = Regular
    b   ask_dollar

select_mid:
    ldr r0, =selected_mid
    bl  printf
    mov r4, #1                     @ 1 = Mid-Grade
    b   ask_dollar

select_prem:
    ldr r0, =selected_prem
    bl  printf
    mov r4, #2                     @ 2 = Premium
    b   ask_dollar

ask_dollar:                        @ === Dollar amount input loop ===
    @ First check if this grade has enough inventory (>=10)
    mov r5, r4                     @ r5 = current grade
    bl  has_enough_inventory
    cmp r0, #0
    beq grade_insufficient_error

    ldr r0, =dollar_prompt
    bl  printf

    ldr r0, =int_format
    ldr r1, =dollar_buf
    bl  scanf

    cmp r0, #1                     @ scanf success?
    bne invalid_dollar_error

    ldr r6, =dollar_buf            @ r6 = dollar amount entered
    ldr r6, [r6]

    cmp r6, #1
    blt invalid_dollar_error
    cmp r6, #50
    bgt invalid_dollar_error

    @ Calculate tenths to dispense based on grade
    bl  calc_tenths                @ Returns tenths in r0
    mov r7, r0                     @ r7 = requested tenths

    @ Check sufficient inventory for this request
    bl  get_current_inventory      @ r0 = current inventory for grade
    cmp r0, r7
    blt insufficient_fuel_error

    @ === Dispense fuel ===
    bl  subtract_inventory         @ Update inventory
    bl  add_dollars                @ Update dollars dispensed

    @ Display result
    mov r1, r7
    ldr r0, =int_format
    bl  printf
    ldr r0, =dispensed
    bl  printf

    b   main_loop

invalid_dollar_error:
    ldr r0, =invalid_dollar
    bl  printf
    b   ask_dollar                 @ Retry dollar amount for same grade

insufficient_fuel_error:
    ldr r0, =insufficient
    bl  printf
    b   ask_dollar                 @ Prompt for lower amount

grade_insufficient_error:
    ldr r0, =insuf_grade
    bl  printf
    b   main_loop

show_status:                       @ === Hidden code handler ===
    bl  print_current_inventory
    bl  print_current_dollars
    b   main_loop

shutdown:                          @ === Final shutdown ===
    ldr r0, =final_inv
    bl  printf
    bl  print_current_inventory

    ldr r0, =final_dol
    bl  printf
    bl  print_current_dollars

    ldr r0, =newline
    bl  printf

    pop {r4-r11, pc}               @ Restore registers and return to OS

@ ====================== Helper Subroutines ======================

print_current_inventory:
    push {lr}
    ldr r0, =inventory_msg
    bl  printf

    ldr r0, =reg_label
    bl  printf
    ldr r0, =inv_reg
    ldr r1, [r0]
    bl  print_number

    ldr r0, =mid_label
    bl  printf
    ldr r0, =inv_mid
    ldr r1, [r0]
    bl  print_number

    ldr r0, =prem_label
    bl  printf
    ldr r0, =inv_prem
    ldr r1, [r0]
    bl  print_number

    pop {pc}

print_current_dollars:
    push {lr}
    ldr r0, =dollars_msg
    bl  printf

    ldr r0, =reg_dol
    bl  printf
    ldr r0, =dol_reg
    ldr r1, [r0]
    bl  print_number

    ldr r0, =mid_dol
    bl  printf
    ldr r0, =dol_mid
    ldr r1, [r0]
    bl  print_number

    ldr r0, =prem_dol
    bl  printf
    ldr r0, =dol_prem
    ldr r1, [r0]
    bl  print_number

    pop {pc}

print_number:                      @ Simple helper to print integer + newline
    push {lr}
    ldr r0, =int_format
    bl  printf
    ldr r0, =newline
    bl  printf
    pop {pc}

@ calc_tenths: r5=grade, r6=dollars → r0=tenths
calc_tenths:
    push {lr}
    cmp r5, #0                     @ Regular: 4 tenths per dollar
    moveq r0, r6, lsl #2
    beq calc_done
    cmp r5, #1                     @ Mid-Grade: 3 tenths per dollar
    moveq r0, #3
    muleq r0, r0, r6
    beq calc_done
    mov r0, r6, lsl #1             @ Premium: 2 tenths per dollar
calc_done:
    pop {pc}

has_enough_inventory:              @ r5=grade → r0=1 if >=10, else 0
    push {lr}
    bl  get_current_inventory
    cmp r0, #10
    movge r0, #1
    movlt r0, #0
    pop {pc}

get_current_inventory:             @ r5=grade → r0=current inventory
    cmp r5, #0
    ldreq r0, =inv_reg
    ldreq r0, [r0]
    cmp r5, #1
    ldreq r0, =inv_mid
    ldreq r0, [r0]
    cmp r5, #2
    ldreq r0, =inv_prem
    ldreq r0, [r0]
    bx  lr

subtract_inventory:                @ r5=grade, r7=tenths to subtract
    push {lr}
    cmp r5, #0
    ldreq r0, =inv_reg
    beq do_subtract
    cmp r5, #1
    ldreq r0, =inv_mid
    beq do_subtract
    ldr r0, =inv_prem
do_subtract:
    ldr r1, [r0]
    sub r1, r1, r7
    str r1, [r0]
    pop {pc}

add_dollars:                       @ r5=grade, r6=dollars to add
    push {lr}
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
    pop {pc}

@ End of program