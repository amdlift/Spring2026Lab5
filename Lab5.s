@ CS309 Lab 5 - Gasoline Pump Simulator
@ Author: Aaron Davis
@ Date: April 10, 2026
@ Term: Spring 2026
@ Email: amd0047@uah.edu
@ Purpose: Simulate a gasoline pump with three grades (R, M, P).
@          Uses stack to preserve registers across calls/loops.
@          Tracks inventory and dollars dispensed. Handles invalid input,
@          insufficient inventory, and hidden status code.

@ To assemble:   as -o Lab5.o Lab5.s
@ To link:       gcc -o Lab5 Lab5.o
@ To run:        ./Lab5
@ To debug:      gdb ./Lab5

.section .data

@ Output strings
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
dispensed_tenths: .asciz " tenths of gallons have been dispensed.\n"
insuf_grade:    .asciz "Insufficient inventory for this grade. Please select another.\n"
final_inventory:.asciz "\nFinal inventory levels:\n"
final_dollars:  .asciz "Final dollar amounts dispensed:\n"
newline:        .asciz "\n"
secret_code:    .asciz "SECRET"   @ Hidden code (case-sensitive, or adjust as needed)

@ Input buffers and formats
grade_input:    .space 10          @ Buffer for grade input
dollar_input:   .space 20          @ Buffer for dollar amount
int_format:     .asciz "%d"        @ For scanf integer
char_format:    .asciz "%s"        @ For scanf string/grade

@ Variables (all in tenths of gallons or cents)
.align 4
inventory_reg:  .word 500
inventory_mid:  .word 500
inventory_prem: .word 500

dollars_reg:    .word 0
dollars_mid:    .word 0
dollars_prem:   .word 0

.section .text
.global main
.extern printf
.extern scanf

main:
    push {r4-r11, lr}              @ Save registers on stack (required for complex program)

    @ Display welcome and initial inventory
    ldr r0, =welcome
    bl  printf

    bl  print_inventory
    bl  print_dollars

main_loop:
    @ Check if all grades are below 10 tenths (1 gallon)
    ldr r0, =inventory_reg
    ldr r1, [r0]
    cmp r1, #10
    blt check_mid
    b   get_grade

check_mid:
    ldr r0, =inventory_mid
    ldr r1, [r0]
    cmp r1, #10
    blt check_prem
    b   get_grade

check_prem:
    ldr r0, =inventory_prem
    ldr r1, [r0]
    cmp r1, #10
    blt shutdown_pump               @ All grades insufficient -> end program

get_grade:
    ldr r0, =select_prompt
    bl  printf

    @ Read grade (as string)
    ldr r0, =char_format
    ldr r1, =grade_input
    bl  scanf

    @ Check for hidden secret code
    ldr r0, =grade_input
    ldr r1, =secret_code
    bl  strcmp                      @ Assume strcmp available or implement simple compare
    cmp r0, #0
    beq show_status

    @ Check single character input (R, M, P) - handle first char
    ldr r0, =grade_input
    ldrb r1, [r0]                   @ Load first byte

    cmp r1, #'R'
    beq select_regular
    cmp r1, #'r'
    beq select_regular

    cmp r1, #'M'
    beq select_mid
    cmp r1, #'m'
    beq select_mid

    cmp r1, #'P'
    beq select_premium
    cmp r1, #'p'
    beq select_premium

    @ Invalid grade
    ldr r0, =invalid_grade
    bl  printf
    b   main_loop

select_regular:
    ldr r0, =selected_reg
    bl  printf
    mov r4, #0                      @ Grade flag: 0=reg, 1=mid, 2=prem
    b   get_dollar_amount

select_mid:
    ldr r0, =selected_mid
    bl  printf
    mov r4, #1
    b   get_dollar_amount

select_premium:
    ldr r0, =selected_prem
    bl  printf
    mov r4, #2
    b   get_dollar_amount

get_dollar_amount:
    @ Check if this grade has enough inventory (>=10)
    mov r5, r4                      @ Save grade
    bl  check_inventory_for_grade
    cmp r0, #0
    beq grade_insufficient

    ldr r0, =dollar_prompt
    bl  printf

    ldr r0, =int_format
    ldr r1, =dollar_input          @ Reuse buffer for int (scanf will parse)
    bl  scanf

    @ Validate input (scanf returns 1 on success)
    cmp r0, #1
    bne invalid_dollar_input

    ldr r0, =dollar_input
    ldr r6, [r0]                   @ Dollar amount in r6

    cmp r6, #1
    blt invalid_dollar_input
    cmp r6, #50
    bgt invalid_dollar_input

    @ Calculate tenths of gallons to dispense
    bl  calculate_tenths           @ r0 = tenths based on grade in r5 and dollars in r6

    @ Check if enough inventory
    mov r7, r0                     @ Save requested tenths
    bl  get_inventory_for_grade    @ r0 = current inventory for this grade
    cmp r0, r7
    blt insufficient_fuel

    @ Dispense: subtract from inventory and add to dollars
    bl  update_inventory
    bl  update_dollars

    @ Display dispensed amount
    ldr r0, =dollar_input          @ Reuse to print number
    str r7, [r0]
    ldr r0, =int_format
    ldr r1, =dollar_input
    bl  printf
    ldr r0, =dispensed_tenths
    bl  printf

    b   main_loop

invalid_dollar_input:
    ldr r0, =invalid_dollar
    bl  printf
    b   get_dollar_amount          @ Retry same grade

insufficient_fuel:
    ldr r0, =insufficient
    bl  printf
    b   get_dollar_amount          @ Prompt for lower amount

grade_insufficient:
    ldr r0, =insuf_grade
    bl  printf
    b   main_loop

show_status:
    bl  print_inventory
    bl  print_dollars
    b   main_loop

shutdown_pump:
    ldr r0, =final_inventory
    bl  printf
    bl  print_inventory

    ldr r0, =final_dollars
    bl  printf
    bl  print_dollars

    ldr r0, =newline
    bl  printf

    pop {r4-r11, pc}               @ Restore registers and return to OS

@ Helper subroutines

print_inventory:
    push {lr}
    ldr r0, =inventory_msg
    bl  printf

    ldr r0, =reg_label
    bl  printf
    ldr r0, =inventory_reg
    ldr r1, [r0]
    bl  print_int

    ldr r0, =mid_label
    bl  printf
    ldr r0, =inventory_mid
    ldr r1, [r0]
    bl  print_int

    ldr r0, =prem_label
    bl  printf
    ldr r0, =inventory_prem
    ldr r1, [r0]
    bl  print_int

    pop {pc}

print_dollars:
    push {lr}
    ldr r0, =dollars_msg
    bl  printf

    ldr r0, =reg_dol
    bl  printf
    ldr r0, =dollars_reg
    ldr r1, [r0]
    bl  print_int

    ldr r0, =mid_dol
    bl  printf
    ldr r0, =dollars_mid
    ldr r1, [r0]
    bl  print_int

    ldr r0, =prem_dol
    bl  printf
    ldr r0, =dollars_prem
    ldr r1, [r0]
    bl  print_int

    pop {pc}

print_int:
    push {r4, lr}
    mov r4, r1
    ldr r0, =int_format
    mov r1, r4
    bl  printf
    ldr r0, =newline
    bl  printf
    pop {r4, pc}

@ calculate_tenths: r5=grade (0,1,2), r6=dollars -> r0=tenths
calculate_tenths:
    push {lr}
    cmp r5, #0
    beq reg_tenths
    cmp r5, #1
    beq mid_tenths
    @ premium
    mov r0, r6, lsl #1             @ 2 tenths per dollar
    pop {pc}
reg_tenths:
    mov r0, r6, lsl #2             @ 4 tenths per dollar
    pop {pc}
mid_tenths:
    mov r0, r6                     @ 3? Wait, table says 3 for mid-grade
    mov r1, #3
    mul r0, r6, r1
    pop {pc}

@ check_inventory_for_grade: r5=grade -> r0=1 if >=10, else 0
check_inventory_for_grade:
    push {lr}
    bl  get_inventory_for_grade
    cmp r0, #10
    movge r0, #1
    movlt r0, #0
    pop {pc}

get_inventory_for_grade:
    cmp r5, #0
    ldreq r0, =inventory_reg
    ldreq r0, [r0]
    cmp r5, #1
    ldreq r0, =inventory_mid
    ldreq r0, [r0]
    cmp r5, #2
    ldreq r0, =inventory_prem
    ldreq r0, [r0]
    bx  lr

update_inventory:
    push {lr}
    cmp r5, #0
    ldreq r0, =inventory_reg
    beq sub_inv
    cmp r5, #1
    ldreq r0, =inventory_mid
    beq sub_inv
    ldr r0, =inventory_prem
sub_inv:
    ldr r1, [r0]
    sub r1, r1, r7                 @ r7 = requested tenths
    str r1, [r0]
    pop {pc}

update_dollars:
    push {lr}
    cmp r5, #0
    ldreq r0, =dollars_reg
    beq add_dol
    cmp r5, #1
    ldreq r0, =dollars_mid
    beq add_dol
    ldr r0, =dollars_prem
add_dol:
    ldr r1, [r0]
    add r1, r1, r6                 @ r6 = dollars
    str r1, [r0]
    pop {pc}

@ End of program