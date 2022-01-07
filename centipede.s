#####################################################################
#
# CSC258H Winter 2021 Assembly Final Project
# University of Toronto, St. George
#
# Student: Guanyu Song, 1006083809
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
# (See the project handout for descriptions of the milestones)
# - Milestone 1,2 and 3
#
# Which approved additional features have been implemented?
# (See the project handout for the list of additional features)
#  None
#
# Any additional information that the TA needs to know:
# The rules of my version of game:
#	1. when dart hits the mushroom, both mushroom and the dart vanishes.
#	2. the centipede has 3 lives. When it is killed, a new centipede will occur
#	3. the game is over when the flea or the centipede touches the bug blaster and a retry option is available
#####################################################################

.data
	
	displayAddress:	.word 0x10008000
	bugLocation: .word 815
	centipedLocation: .word 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
	centipedDirection: .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	centipedLives: .word 3
	mushroomLocation: .word -1:32
	dartLocation: .word -1:24
	fleaLocation: .word -1	
	gameOver: .word 230, 231, 234, 237, 240, 242, 243, 244, 261, 265, 267, 269, 270, 271, 272, 274, 293, 297, 298, 299, 301, 304, 306, 307, 308, 325, 327, 329, 331, 333, 336, 338, 358, 359, 361, 363, 365, 368, 370, 371, 372, 422, 423, 426, 428, 430, 431, 432, 434, 435, 436, 453, 456, 458, 460, 462, 466, 468, 485, 488, 490, 492, 494, 495, 496, 498, 499, 517, 550, 520, 522, 524, 526, 530, 532, 551, 555, 558, 559, 560, 562, 564
	msg: .asciiz "Select Yes to restart the game, No or Cancel to exit."



.text 

START: #start the program
	addi $a3, $zero, 24
	la $a1, dartLocation
	addi $t1, $zero, -1
dart_reset: #reset the existing dart
	sw $t1, 0($a1)
	addi $a3, $a3, -1 #set the location of the dart to -1
	addi $a1, $a1, 4
	bne $a3, $zero, dart_reset

mus_reset: #reset the existing mushroom
	addi $a3, $a3, 32
	lw $t1, displayAddress 
	li $t2, 0x00ff00	#mushrooms are green
	la $t4, mushroomLocation
mus_loop:	#create random mushrooms
	#get random number from 12 to 768 (above the bug blaster)
	li $v0, 42		
	li $a0, 0
	li $a1, 756
	syscall
	addi $a0, $a0, 12
	
	sw $a0, 0($t4) #save the mushroom location
	
	sll $t3, $a0, 2
	add $t3, $t1, $t3
	sw $t2, 0($t3) #draw the mushroom
	
	addi $a3, $a3, -1 # counter minus 1
	addi $t4, $t4, 4 #address of the location array increment by 4
	bne $a3, $zero, mus_loop
	
Loop: #main loop
	jal disp_centiped
	jal check_keystroke
	jal dart_update
	jal flea_update
	jal redraw_mushrooms
	
	li $v0, 32		 #sleep
	li $a0, 100
	syscall
	
	j Loop	

Exit:
	li $v0, 10		# terminate the program gracefully
	syscall


# display centipede
disp_centiped:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $a1, centipedLocation # load the address of the array into $a1
	la $a2, centipedDirection # load the address of the array into $a2

	lw $t1, 0($a1)		 # load a word from the centipedLocation array into $t1
	lw $t5, 0($a2)		 # load a word from the centipedDirection  array into $t5
	#####
	lw $t2, displayAddress  # $t2 stores the base address for display
	li $t3, 0x000000
	sub $t6, $t1, $t5
	sll $t4,$t6, 2		# $t4 is the bias of the old body location in memory (offset*4)
	add $t4, $t2, $t4	# $t4 is the address of the old bug location
	sw $t3, 0($t4)		# paint the tail of the centipede with black
	
	li $t3, 0xff0000	# $t3 stores the red colour code
	
	addi $a3, $zero, 10
	la $a1, centipedLocation # load the address of the array into $a1
	la $a2, centipedDirection # load the address of the array into $a2
	
arr_loop:	#iterate over the loops elements to draw each body in the centiped
	lw $t1, 0($a1)		 # load a word from the centipedLocation array into $t1
	lw $t5, 0($a2)		 # load a word from the centipedDirection  array into $t5
	
	addi $t6, $zero, 32
	div $t1, $t6
	mfhi $t6
	addi $t7, $zero, 31
	
	bne $t7, $t6, ELSE1	#if t1%32 != 31, i.e, not at the right end of the screen, go to ELSE1
	
	addi $t6, $zero, 32
	bne $t5, $t6, ELSE2	#if t1%32==31 and t5!=32, i.e, at the right end of the screen and is not moving down, go to ELSE2
	addi $t6, $zero, -1
	sw $t6, 0($a2)         # if t1%32==31 and t5==32, i.e, at the right end of the screen and is moving down, set the direction to be -1 
	j END
ELSE1: 
	addi $t7, $zero, 0
	addi $t2, $zero, 32
	la $t3, mushroomLocation
	bne $t7, $t6, ELSE3     #if t1%32 !=0, i.e, not at the left end, go to ELSE3
	
	addi $t6, $zero, 32
	bne $t5, $t6, ELSE2   #if t1%32 == 0 and t5 != 32, i.e, at the left end but not moving down, go to ELSE2
	addi $t6, $zero, 1
	sw $t6, 0($a2)		#if t1%32 == 0 and t5 == 32, i.e, at the left end and is moving down, set the direction to be 1
	j END
ELSE2:
	addi $t6, $zero, 32
	sw $t6, 0($a2)	      #set direction to be 32 (move down)
	j END
ELSE3:	#ELSE3, ELSE4 and ELSE 5 checks any mushroom encountered. ELSE3 is a loop
	lw $t4, 0($t3)
	addi $t6, $t4, 1
	beq $t6, $t1, ELSE2
	addi $t6, $t4, -1
	beq $t6, $t1, ELSE2
	addi $t6, $t4, 31
	beq $t6, $t1, ELSE4
	addi $t6, $t4, 33
	beq $t6, $t1, ELSE5
	j E
ELSE4:
	addi $t6, $zero, 32
	bne $t6, $t5, E
	addi $t6, $zero, -1
	sw $t6, 0($a2)
	j E
ELSE5:
	addi $t6, $zero, 32
	bne $t6, $t5, E
	addi $t6, $zero, 1
	sw $t6, 0($a2)
	j E
E:	
	addi $t3, $t3, 4
	addi $t2, $t2, -1
	bne $t2, $zero, ELSE3
	
END:
	#paint the updated body of the centipede
	lw $t2, displayAddress  # $t2 stores the base address for display
	li $t3, 0xff0000	# $t3 stores the red colour code
	
	sll $t4,$t1, 2		# $t4 is the bias of the old body location in memory (offset*4)
	add $t4, $t2, $t4	# $t4 is the address of the old bug location
	sw $t3, 0($t4)		# paint the body with red

	lw $t5, 0($a2)		#update location
	add $t6, $t1, $t5	
	sw $t6, 0($a1)
	
	addi $a1, $a1, 4	 # increment $a1 by one, to point to the next element in the array
	addi $a2, $a2, 4
	addi $a3, $a3, -1	 # decrement $a3 by 1
	bne $a3, $zero, arr_loop
	
	
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra



# function to detect any keystroke
check_keystroke:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
Bugblaster: #draw and check the bugblaster
	lw $t1, displayAddress
	li $t3, 0xffffff	# $t3 stores the white colour code
	la $a1, bugLocation
	lw $t2, 0($a1)
	
	la $a2, fleaLocation
	lw $t5, 0($a2)
	beq $t2, $t5, respond_to_s	#if bugblaster has the same location as the flea, game over
	la $a2, centipedLocation	
	addi $a2, $a2, 36
	lw $t5, 0($a2)
	beq $t2, $t5, respond_to_s	#if bugblaster is hit by the head of the centipede, game over
	
	sll $t4,$t2, 2
	add $t4, $t1, $t4
	sw $t3, 0($t4)
	
#get key input:	
	lw $t8, 0xffff0000		
	beq $t8, 1, get_keyboard_input # if key is pressed, jump to get this key
	addi $t8, $zero, 0
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
# function to get the input key
get_keyboard_input:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t2, 0xffff0004
	addi $v0, $zero, 0	#default case
	beq $t2, 0x6A, respond_to_j
	beq $t2, 0x6B, respond_to_k
	beq $t2, 0x78, respond_to_x
	beq $t2, 0x73, respond_to_s
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
# Call back function of j key
respond_to_j:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, bugLocation	# load the address of buglocation from memory
	lw $t1, 0($t0)		# load the bug location itself in t1
	
	lw $t2, displayAddress  # $t2 stores the base address for display
	li $t3, 0x000000	# $t3 stores the black colour code
	
	sll $t4,$t1, 2		# $t4 the bias of the old buglocation
	add $t4, $t2, $t4	# $t4 is the address of the old bug location
	sw $t3, 0($t4)		# paint the first (top-left) unit black.
	
	beq $t1, 800, skip_movement # prevent the bug from getting out of the canvas
	addi $t1, $t1, -1	# move the bug one location to the right
skip_movement:
	sw $t1, 0($t0)		# save the bug location

	li $t3, 0xffffff	# $t3 stores the white colour code
	
	sll $t4,$t1, 2
	add $t4, $t2, $t4
	sw $t3, 0($t4)		# paint the first (top-left) unit white.
	
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

# Call back function of k key
respond_to_k:
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $t0, bugLocation	# load the address of buglocation from memory
	lw $t1, 0($t0)		# load the bug location itself in t1
	
	lw $t2, displayAddress  # $t2 stores the base address for display
	li $t3, 0x000000	# $t3 stores the black colour code
	
	sll $t4,$t1, 2		# $t4 the bias of the old buglocation
	add $t4, $t2, $t4	# $t4 is the address of the old bug location
	sw $t3, 0($t4)		# paint the block with black
	
	beq $t1, 831, skip_movement2 #prevent the bug from getting out of the canvas
	addi $t1, $t1, 1	# move the bug one location to the right
skip_movement2:
	sw $t1, 0($t0)		# save the bug location

	li $t3, 0xffffff	# $t3 stores the white colour code
	
	sll $t4,$t1, 2
	add $t4, $t2, $t4
	sw $t3, 0($t4)		# paint the block with white
	
	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
	
respond_to_x: # shoot the darts
	# move stack pointer a work and push ra onto it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	addi $a3, $zero, 24
	la $a1, dartLocation
	la $a2, bugLocation
	lw $t1, 0($a2)
add_dart_loop: #replace a negative location in the dartLocation array with a new location
	lw $t2, 0($a1)
	bgtz $t2, x_lb1		#if the current dart location is larger than zero, skip to the next location
	sw $t1, 0($a1)		# if the current dart location is negative, replace it with the location of the bug blaster and break the loop
	j x_lb2
x_lb1:
	addi $a1, $a1, 4
	addi $a3, $a3, -1
	bne $a3, $zero, add_dart_loop
x_lb2:	
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra


respond_to_s: #it means game over
reset_bug:	#reset the location of the bug to 815
	la $a1, bugLocation
	addi $t1, $zero, 815
	sw $t1, 0($a1)
reset_flea:	#reset the location of the flea to -1
	la $a1, fleaLocation
	addi $t1, $zero, -1
	sw $t1, 0($a1)
reset_lives:	#reset the lives of the centipede to 3
	la $a1, centipedLives
	addi $t1, $zero, 3
	sw $t1, 0($a1)
# repaint the screen black:
	lw $t1, displayAddress 
	li $t2, 0x000000	#black
	addi $a3, $zero, 4096
reset_screen:	
	add $t3, $t1, $a3
	sw $t2, 0($t3)
	addi $a3, $a3, -4
	bne $a3, $zero, reset_screen
#reset the location of the centipede to be 2-11
	addi $a3, $zero, 10
	addi $t1, $zero, 1
	addi $t2, $zero, 2
	la $a1, centipedLocation
	la $a2, centipedDirection
reset_centipede:	
	sw $t2, 0($a1)
	sw $t1, 0($a2)
	addi $a3, $a3, -1
	addi $a2, $a2, 4
	addi $a1, $a1, 4
	addi $t2, $t2, 1
	bne $a3, $zero, reset_centipede
#game over
	j game_over

flea_update:	#update and draw the flea
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	la $a2, fleaLocation
	lw $t3, 0($a2)
	bltz $t3, flea_lb1	#if the location is negative, skip
	lw $t1, displayAddress
	li $t2, 0xfff000 # orange flea
	li $t4, 0x000000
	
	sll $t5, $t3, 2
	add $t5, $t5, $t1
	sw $t4, 0($t5)	#paint the current location black
	
	addi $t3, $t3, 32	#increment the location of the flea by 32(move down)
	addi $t5, $t3, -1024	
	bgtz $t5, flea_lb2	#if the location is out of boundary, set it to be -1
	sw $t3, 0($a2)
	
	sll $t5, $t3, 2		
	add $t5, $t5, $t1
	sw $t2, 0($t5)		#else paint the new flea
	j flea_lb3
flea_lb1: # if the location of the flea is negative, randomly create a new one
	li $v0, 42		
	li $a0, 0
	li $a1, 300
	syscall		#a0 is now a random integer ranging from 0 to 300
	addi $t5, $a0, -32
	bgtz $t5, flea_lb3	#only when a0 is 0-31 it's stored as the new location. So the occurrence of the flea is also random
	sw $a0, 0($a2)
	
	j flea_lb3	
flea_lb2:	#set the location of the flea to be -1
	addi $t3, $zero, -1
	sw $t3, 0($a1)
flea_lb3:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
#update and draw the darts
dart_update:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	addi $a3, $zero, 24
	la $a1, dartLocation
	lw $t1, displayAddress
	li $t2, 0x00ffff # blue dart
	li $t4, 0x000000 #black
dart_loop:
	lw $t3, 0($a1)
#for each dart, check if it encounters a mushroom?	
	addi $t5, $zero, 32
	la $a2, mushroomLocation
	addi $t7, $zero, -1
check_mus:	
	lw $t6, 0($a2)
	bne $t3, $t6, check_mus_lb1	#if the location of the dart is not the same as the current mushroom, skip to the next mushroom
	sw $t7, 0($a2)
	sw $t7, 0($a1)
	sll $t6, $t6, 2
	add $t6, $t6, $t1
	sw $t4, 0($t6)
	addi $t3, $t7, 0
	j check_lb1
check_mus_lb1:
	addi $a2, $a2, 4
	addi $t5, $t5, -1
	bne $t5, $zero, check_mus	
#check if it encounters a flea:
	la $a2, fleaLocation
	addi $t7, $zero, -1
check_flea:	#since the flea is moving, it's a little bit more complicated. 
		#The idea is the flea and the dart vanish if their locations are the same or differ by 32
	lw $t6, 0($a2)
	beq $t3, $t6, check_flea_lb1
	addi $t5, $t6, -32
	beq $t3, $t5, check_flea_lb1
	addi $t5, $t6, 32
	beq $t3, $t5, check_flea_lb1
	j check_flea_lb2
check_flea_lb1:
	sw $t7, 0($a2)
	sw $t7, 0($a1)
	sll $t3, $t3, 2
	add $t3, $t3, $t1
	sw $t4, 0($t3)
	
	sll $t6, $t6, 2
	add $t6, $t6, $t1
	sw $t4, 0($t6)
	addi $t3, $t7, 0
check_flea_lb2:
#check if the dart encounters the centipede:
	addi $t5, $zero, 10
	la $a2, centipedLocation
	addi $t7, $zero, -1
check_centipede:
	lw $t6, 0($a2)
	bne $t3, $t6, check_centipede_lb1	#if the dart and the centipede body don't share location, skip to the next centipede body
	sw $t7, 0($a1)		#when the dart hits hte centipede, set the dart location to be -1
	addi $t3, $t7, 0
	la $a2, centipedLives		
	lw $t6, 0($a2)
	add $t6, $t6, $t7
	sw $t6, 0($a2)		#when dart hits the centipede, reduce the lives of the centipede by 1
	beq $t6, $zero, new_centipede	#if the lives of the centipede is zero, reset the centipede
	j check_lb1
new_centipede:	#reset the centipede
	addi $t5, $zero, 10
	la $a2, centipedLocation
	la $t3, centipedDirection 
	lw $a0, 0($a2)
	lw $t6, 0($t3)
	sub $a0, $a0, $t6
	sll $a0, $a0, 2
	add $a0, $a0, $t1
	sw $t4, 0($a0)
	
	addi $t6, $zero, 1
	addi $t7, $zero, 2
new_loop:
	lw $a0, 0($a2)
	sll $a0, $a0, 2
	add $a0, $a0, $t1
	sw $t4, 0($a0)		#paint the old body black
	
	sw $t7, 0($a2)
	sw $t6, 0($t3)
	addi $t5, $t5, -1
	addi $a2, $a2, 4
	addi $t3, $t3, 4
	addi $t7, $t7, 1	#set the new location and direction
	bne $t5, $zero, new_loop
	
	la $a2, centipedLives
	addi $t3, $zero, 3
	sw $t3, 0($a2)		#set the lives of the centipede back to 3
	
	addi $t3, $zero, -1
	j check_lb1	#break the loop
check_centipede_lb1:
	addi $a2, $a2, 4
	addi $t5, $t5, -1
	bne $t5, $zero, check_centipede

check_lb1:	
	bltz $t3, dart_lb1	#if the new dart location is negative, skip the current dart
	sll $t5, $t3, 2
	add $t5, $t5, $t1
	sw $t4, 0($t5)		#else paint the old dart black
	
	addi $t3, $t3 -32
	sw $t3, 0($a1)  	#save the new location

	sll $t3, $t3, 2
	add $t3, $t3, $t1
	sw $t2, 0($t3)		#draw the new dart
dart_lb1:
	addi $a1, $a1, 4
	addi $a3, $a3, -1
	bne $a3, $zero, dart_loop
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
#redraw the mushrooms according to the locations
redraw_mushrooms:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	lw $t1, displayAddress 
	li $t2, 0x00ff00	#mushrooms are green
	addi $a3, $zero, 32
	la $a1, mushroomLocation
draw:
	lw $t3, 0($a1)
	bltz $t3, mus_lb1 
	sll $t3, $t3, 2
	add $t3, $t1, $t3
	sw $t2, 0($t3)
mus_lb1:	
	addi $a1, $a1, 4
	addi $a3, $a3, -1
	bne $a3, $zero, draw
	# pop a word off the stack and move the stack pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
#when the game is over
game_over:
	addi $a3, $zero, 82
	la $a1, gameOver
	lw $t1, displayAddress
	li $a2, 0xffffff
over_loop:	#this loop displays the "game over pattern on the screen"
	lw $t2, 0($a1)
	addi $t2, $t2, 99
	sll $t2, $t2, 2
	add $t2, $t2, $t1
	sw $a2, 0($t2)
	addi $a1, $a1, 4
	addi $a3, $a3, -1
	bne $a3, $zero, over_loop
	
	lw $t1, displayAddress 
	li $t2, 0x000000	#black
	add $a3, $t1, 396
	sw $t2, 0($a3)
	
	li $v0, 32		 #sleep
	li $a0, 1500
	syscall
#ask if restart
restart: #system call dialog to ask if restart the game
	li $v0, 50
	la $a0, msg
	syscall
	
	bne $a0, $zero, Exit #if not yes, exit
# else clean the screen and go back to the beginning of this program
	addi $a3, $zero, 1024
clean_screen:
	addi $a3, $a3, -1
	sll $t3, $a3, 2
	add $t3, $t3, $t1
	sw $t2, 0($t3)
	bne $a3, $zero, clean_screen
	
	j START


