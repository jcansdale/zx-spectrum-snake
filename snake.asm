; ============================================
; SNAKE GAME FOR ZX SPECTRUM
; Written in Z80 Assembly
; Assemble with PASMO: pasmo snake.asm snake.tap
; ============================================

        ORG 32768           ; Start at address 32768

; ============================================
; SYSTEM VARIABLES AND ROM ROUTINES
; ============================================
LAST_K      EQU 23560       ; Last key pressed
FRAMES      EQU 23672       ; Frame counter (for timing)
ATTR_P      EQU 23693       ; Permanent attribute
BORDCR      EQU 23624       ; Border color

; ROM Routines
ROM_CLS     EQU 0x0DAF      ; Clear screen
ROM_PRINT   EQU 0x203C      ; Print a character

; Screen dimensions (in characters)
SCREEN_W    EQU 32
SCREEN_H    EQU 22          ; Leave 2 rows for score
SCREEN_TOP  EQU 2           ; Start 2 rows down for score display

; Attribute addresses
ATTR_START  EQU 22528

; Direction constants
DIR_UP      EQU 0
DIR_DOWN    EQU 1
DIR_LEFT    EQU 2
DIR_RIGHT   EQU 3

; Game constants
MAX_LENGTH  EQU 256         ; Maximum snake length
INITIAL_LEN EQU 5           ; Initial snake length
GAME_SPEED  EQU 8           ; Lower = faster (frames between moves)

; Colors
INK_BLACK   EQU 0
INK_BLUE    EQU 1
INK_RED     EQU 2
INK_MAGENTA EQU 3
INK_GREEN   EQU 4
INK_CYAN    EQU 5
INK_YELLOW  EQU 6
INK_WHITE   EQU 7
PAPER_BLACK EQU 0
PAPER_BLUE  EQU 8
PAPER_RED   EQU 16
PAPER_GREEN EQU 32
PAPER_YELLOW EQU 48
BRIGHT      EQU 64
FLASH       EQU 128

; ============================================
; MAIN ENTRY POINT
; ============================================
Start:
        CALL InitGame       ; Initialize game state
        CALL DrawBorder     ; Draw the playing field border
        CALL DrawScore      ; Draw initial score
        
MainLoop:
        CALL WaitFrame      ; Wait for timing
        CALL ReadInput      ; Read keyboard input
        CALL MoveSnake      ; Move the snake
        CALL CheckCollision ; Check for collisions
        
        LD A,(GameOver)
        OR A
        JR NZ,GameOverScreen
        
        JR MainLoop
        
GameOverScreen:
        CALL ShowGameOver
        
        ; Wait for key press to restart
WaitKey:
        LD A,(LAST_K)
        CP 32               ; Space to restart
        JR NZ,WaitKey
        
        ; Clear key buffer
        XOR A
        LD (LAST_K),A
        
        JR Start            ; Restart game

; ============================================
; INITIALIZE GAME STATE
; ============================================
InitGame:
        ; Clear screen
        CALL ROM_CLS
        
        ; Fill entire attribute area with black
        LD HL,0x5800        ; Attribute memory start
        LD DE,0x5801
        LD BC,767           ; 768 bytes - 1
        XOR A               ; Black (ink 0, paper 0)
        LD (HL),A
        LDIR                ; Fill all attributes with black
        
        ; Set border color to blue
        LD A,1
        LD (BORDCR),A
        OUT (254),A
        
        ; Initialize game variables
        XOR A
        LD (GameOver),A
        LD (Direction),A    ; Start moving up
        LD A,DIR_RIGHT
        LD (Direction),A    ; Actually start moving right
        
        ; Initialize score
        XOR A
        LD (Score),A
        LD (Score+1),A
        
        ; Initialize snake length
        LD A,INITIAL_LEN
        LD (SnakeLength),A
        
        ; Initialize snake position (middle of screen)
        LD HL,SnakeX
        LD DE,SnakeY
        
        ; Set initial snake segments
        ; Head at index 0 (rightmost), tail at index INITIAL_LEN-1 (leftmost)
        ; Snake moves right, so head is at X=16, body extends left
        
        ; Index 0: head at X=16, Y=12
        ; Index 1: X=15, Y=12
        ; Index 2: X=14, Y=12
        ; etc.
        
        LD B,INITIAL_LEN
        XOR A               ; Start at index 0
        LD C,A
        
InitSnakeLoop:
        PUSH BC
        
        ; Calculate X position: 16 - index (head at 16, tail segments to left)
        LD A,16
        SUB C
        
        ; Store X at SnakeX[C]
        LD B,0
        LD HL,SnakeX
        ADD HL,BC
        LD (HL),A
        
        ; Store Y at SnakeY[C] (always 12)
        LD HL,SnakeY
        ADD HL,BC
        LD A,12
        LD (HL),A
        
        POP BC
        INC C               ; Next index
        DJNZ InitSnakeLoop
        
        ; Initialize head and tail pointers
        XOR A
        LD (HeadPtr),A      ; Head at index 0 (X=16)
        LD A,INITIAL_LEN
        DEC A
        LD (TailPtr),A      ; Tail at index 4 (X=12)
        
        ; Place initial food
        CALL PlaceFood
        
        ; Draw initial snake
        CALL DrawSnake
        
        RET

; ============================================
; DRAW BORDER
; ============================================
DrawBorder:
        ; Draw top border
        LD B,SCREEN_W
        LD C,0              ; X position
        LD D,SCREEN_TOP-1   ; Y position (row 1)
        
DrawTopBorder:
        PUSH BC
        LD A,C
        LD B,D
        CALL SetAttr
        ; Rainbow color based on X position (paper color = ink * 8)
        POP BC
        PUSH BC
        LD A,C
        AND 7               ; Get color 0-7
        RLCA
        RLCA
        RLCA                ; Shift to paper bits (multiply by 8)
        OR BRIGHT           ; Add bright
        CALL WriteAttr
        POP BC
        INC C
        DJNZ DrawTopBorder
        
        ; Draw bottom border
        LD B,SCREEN_W
        LD C,0
        LD D,SCREEN_TOP+SCREEN_H
        
DrawBottomBorder:
        PUSH BC
        LD A,C
        LD B,D
        CALL SetAttr
        ; Rainbow color based on X position (paper color = ink * 8)
        POP BC
        PUSH BC
        LD A,C
        AND 7
        RLCA
        RLCA
        RLCA                ; Shift to paper bits
        OR BRIGHT
        CALL WriteAttr
        POP BC
        INC C
        DJNZ DrawBottomBorder
        
        ; Draw left border
        LD B,SCREEN_H
        LD C,0
        LD D,SCREEN_TOP
        
DrawLeftBorder:
        PUSH BC
        LD A,C
        LD B,D
        CALL SetAttr
        LD A,INK_BLACK + PAPER_BLUE + BRIGHT
        CALL WriteAttr
        POP BC
        INC D
        DJNZ DrawLeftBorder
        
        ; Draw right border  
        LD B,SCREEN_H
        LD C,SCREEN_W-1
        LD D,SCREEN_TOP
        
DrawRightBorder:
        PUSH BC
        LD A,C
        LD B,D
        CALL SetAttr
        LD A,INK_BLACK + PAPER_BLUE + BRIGHT
        CALL WriteAttr
        POP BC
        INC D
        DJNZ DrawRightBorder
        
        RET

; ============================================
; DRAW SCORE AT TOP OF SCREEN
; ============================================
DrawScore:
        ; Print "SCORE:" at position 0,0
        LD DE,ScoreText
        LD BC,6
        CALL PrintString
        
        ; Print score value
        LD HL,(Score)
        CALL PrintNumber
        RET

ScoreText:
        DEFB "SCORE:"

; ============================================
; PRINT STRING AT CURRENT POSITION
; ============================================
PrintString:
        LD A,(DE)
        RST 16              ; Print character
        INC DE
        DEC BC
        LD A,B
        OR C
        JR NZ,PrintString
        RET

; ============================================
; PRINT 16-BIT NUMBER IN HL
; ============================================
PrintNumber:
        LD A,H
        OR L
        JR NZ,PrintNum1
        LD A,'0'
        RST 16
        RET
        
PrintNum1:
        LD BC,-10000
        CALL Num1
        LD BC,-1000
        CALL Num1
        LD BC,-100
        CALL Num1
        LD BC,-10
        CALL Num1
        LD A,L
        ADD A,'0'
        RST 16
        RET
        
Num1:
        LD A,'0'-1
Num2:
        INC A
        ADD HL,BC
        JR C,Num2
        SBC HL,BC
        CP '0'
        RET Z               ; Skip leading zeros
        RST 16
        RET

; ============================================
; WAIT FOR FRAME (GAME TIMING)
; ============================================
WaitFrame:
        LD B,GAME_SPEED
WaitLoop:
        HALT                ; Wait for interrupt
        DJNZ WaitLoop
        RET

; ============================================
; READ KEYBOARD INPUT
; ============================================
ReadInput:
        ; Check Q key (up)
        LD BC,0xFBFE        ; Port for Q key
        IN A,(C)
        BIT 0,A
        JR NZ,CheckA
        
        LD A,(Direction)
        CP DIR_DOWN         ; Can't go up if moving down
        RET Z
        LD A,DIR_UP
        LD (Direction),A
        RET
        
CheckA:
        ; Check A key (down)
        LD BC,0xFDFE        ; Port for A key
        IN A,(C)
        BIT 0,A
        JR NZ,CheckO
        
        LD A,(Direction)
        CP DIR_UP           ; Can't go down if moving up
        RET Z
        LD A,DIR_DOWN
        LD (Direction),A
        RET
        
CheckO:
        ; Check O key (left)
        LD BC,0xDFFE        ; Port for O key
        IN A,(C)
        BIT 1,A
        JR NZ,CheckP
        
        LD A,(Direction)
        CP DIR_RIGHT        ; Can't go left if moving right
        RET Z
        LD A,DIR_LEFT
        LD (Direction),A
        RET
        
CheckP:
        ; Check P key (right)
        LD BC,0xDFFE        ; Port for P key
        IN A,(C)
        BIT 0,A
        RET NZ
        
        LD A,(Direction)
        CP DIR_LEFT         ; Can't go right if moving left
        RET Z
        LD A,DIR_RIGHT
        LD (Direction),A
        RET

; ============================================
; MOVE SNAKE
; ============================================
MoveSnake:
        ; Get current head position
        LD A,(HeadPtr)
        LD C,A
        LD B,0
        
        LD HL,SnakeX
        ADD HL,BC
        LD A,(HL)
        LD D,A              ; D = head X
        
        LD HL,SnakeY
        ADD HL,BC
        LD A,(HL)
        LD E,A              ; E = head Y
        
        ; Calculate new head position based on direction
        LD A,(Direction)
        
        CP DIR_UP
        JR NZ,CheckDown
        DEC E               ; Move up (Y--)
        JR MoveDone
        
CheckDown:
        CP DIR_DOWN
        JR NZ,CheckLeft
        INC E               ; Move down (Y++)
        JR MoveDone
        
CheckLeft:
        CP DIR_LEFT
        JR NZ,DoRight
        DEC D               ; Move left (X--)
        JR MoveDone
        
DoRight:
        INC D               ; Move right (X++)
        
MoveDone:
        ; Save new head position to memory
        LD A,D
        LD (NewHeadX),A
        LD A,E
        LD (NewHeadY),A
        
        ; Check if food eaten (compare food position with new head position)
        LD A,(FoodX)
        LD B,A
        LD A,(NewHeadX)
        CP B
        JR NZ,NoFood
        LD A,(FoodY)
        LD B,A
        LD A,(NewHeadY)
        CP B
        JR NZ,NoFood
        
        ; Food eaten! Grow snake and place new food
        LD A,(SnakeLength)
        CP MAX_LENGTH-1
        JR NC,NoGrow        ; Don't grow if at max length
        INC A
        LD (SnakeLength),A
        
NoGrow:
        ; Increase score
        LD HL,(Score)
        LD BC,10
        ADD HL,BC
        LD (Score),HL
        
        ; Place new food
        CALL PlaceFood
        CALL DrawScore
        
        JR UpdateHead
        
NoFood:
        ; Get tail position
        LD A,(TailPtr)
        LD C,A
        LD B,0
        
        ; Get tail X
        LD HL,SnakeX
        ADD HL,BC
        LD D,(HL)           ; D = tail X
        
        ; Get tail Y
        LD HL,SnakeY
        ADD HL,BC
        LD E,(HL)           ; E = tail Y
        
        ; Clear tail cell on screen
        LD A,D              ; A = tail X
        LD B,E              ; B = tail Y
        CALL SetAttr        ; HL = attribute address
        XOR A               ; A = 0 (black)
        LD (HL),A           ; Clear the attribute
        
        ; Update tail pointer (decrement to follow head direction)
        LD A,(TailPtr)
        DEC A
        AND MAX_LENGTH-1    ; Wrap around
        LD (TailPtr),A
        
UpdateHead:
        ; Update head pointer
        LD A,(HeadPtr)
        DEC A
        AND MAX_LENGTH-1    ; Wrap around
        LD (HeadPtr),A
        
        ; Store new head position
        LD C,A
        LD B,0
        
        LD A,(NewHeadX)
        LD D,A
        LD HL,SnakeX
        ADD HL,BC
        LD (HL),D
        
        LD A,(NewHeadY)
        LD E,A
        LD HL,SnakeY
        ADD HL,BC
        LD (HL),E
        
        ; First, redraw old head position as body (green)
        ; Old head is now at HeadPtr + 1
        LD A,(HeadPtr)
        INC A
        AND MAX_LENGTH-1
        LD C,A
        LD B,0
        
        LD HL,SnakeX
        ADD HL,BC
        LD A,(HL)
        PUSH AF             ; Save old head X
        
        LD HL,SnakeY
        ADD HL,BC
        LD A,(HL)
        LD B,A              ; B = old head Y
        POP AF              ; A = old head X
        
        CALL SetAttr
        LD A,INK_BLACK + PAPER_GREEN + BRIGHT
        CALL WriteAttr
        
        ; Now draw new head (yellow)
        LD A,(NewHeadX)
        LD D,A
        LD A,(NewHeadY)
        LD B,A
        LD A,D
        CALL SetAttr
        LD A,INK_BLACK + PAPER_YELLOW + BRIGHT
        CALL WriteAttr
        
        RET

; ============================================
; CHECK COLLISION
; ============================================
CheckCollision:
        ; Get head position
        LD A,(HeadPtr)
        LD C,A
        LD B,0
        
        LD HL,SnakeX
        ADD HL,BC
        LD A,(HL)
        LD D,A              ; D = head X
        
        LD HL,SnakeY
        ADD HL,BC
        LD A,(HL)
        LD E,A              ; E = head Y
        
        ; Check wall collision
        LD A,D
        OR A
        JR Z,Collision      ; Hit left wall
        CP SCREEN_W-1
        JR NC,Collision     ; Hit right wall
        
        LD A,E
        CP SCREEN_TOP
        JR C,Collision      ; Hit top wall
        CP SCREEN_TOP+SCREEN_H
        JR NC,Collision     ; Hit bottom wall
        
        ; Check self collision
        LD A,(SnakeLength)
        LD B,A
        DEC B               ; Don't check head against itself
        DEC B               ; Skip one more segment
        
        LD A,B
        OR A
        RET Z               ; Snake too short for self collision
        
        LD A,(HeadPtr)
        INC A
        INC A
        AND MAX_LENGTH-1
        LD C,A              ; Start from segment after head
        
CheckSelfLoop:
        PUSH BC
        
        LD B,0
        LD HL,SnakeX
        ADD HL,BC
        LD A,(HL)
        CP D
        JR NZ,NextSegment
        
        LD HL,SnakeY
        ADD HL,BC
        LD A,(HL)
        CP E
        JR Z,CollisionPop
        
NextSegment:
        POP BC
        INC C
        LD A,C
        AND MAX_LENGTH-1
        LD C,A
        DJNZ CheckSelfLoop
        
        RET                 ; No collision
        
CollisionPop:
        POP BC
        
Collision:
        ; Flash border red on collision
        LD A,2              ; Red border
        OUT (254),A
        
        ; Flash effect
        LD B,10
FlashLoop:
        HALT
        DJNZ FlashLoop
        
        LD A,1
        LD (GameOver),A
        RET

; ============================================
; PLACE FOOD AT RANDOM POSITION
; ============================================
PlaceFood:
        ; Use FRAMES as pseudo-random seed
PlaceFoodLoop:
        LD A,(FRAMES)
        LD B,A
        LD A,R              ; Use refresh register for more randomness
        ADD A,B
        
        ; Calculate X position (1 to SCREEN_W-2)
        AND 31              ; 0-31
        CP SCREEN_W-1
        JR NC,PlaceFoodLoop
        OR A
        JR Z,PlaceFoodLoop
        LD D,A              ; D = food X
        
        ; Calculate Y position
        LD A,(FRAMES+1)
        LD B,A
        LD A,R
        ADD A,B
        
        AND 31
        CP SCREEN_H
        JR NC,PlaceFoodLoop
        ADD A,SCREEN_TOP
        LD E,A              ; E = food Y
        
        ; Check if position is on snake
        PUSH DE
        CALL CheckPosOnSnake
        POP DE
        JR C,PlaceFoodLoop  ; If on snake, try again
        
        ; Store food position
        LD A,D
        LD (FoodX),A
        LD A,E
        LD (FoodY),A
        
        ; Draw food (flashing red/yellow)
        LD A,D
        LD B,E
        CALL SetAttr
        LD A,INK_BLACK + PAPER_RED + BRIGHT
        CALL WriteAttr
        
        RET

; ============================================
; CHECK IF POSITION (D,E) IS ON SNAKE
; Returns: Carry set if on snake
; ============================================
CheckPosOnSnake:
        LD A,(SnakeLength)
        LD B,A
        LD A,(HeadPtr)
        LD C,A
        
CheckPosLoop:
        PUSH BC
        LD B,0
        
        LD HL,SnakeX
        ADD HL,BC
        LD A,(HL)
        CP D
        JR NZ,NotOnSnake
        
        LD HL,SnakeY
        ADD HL,BC
        LD A,(HL)
        CP E
        JR Z,OnSnake
        
NotOnSnake:
        POP BC
        INC C
        LD A,C
        AND MAX_LENGTH-1
        LD C,A
        DJNZ CheckPosLoop
        
        OR A                ; Clear carry
        RET
        
OnSnake:
        POP BC
        SCF                 ; Set carry
        RET

; ============================================
; DRAW ENTIRE SNAKE
; ============================================
DrawSnake:
        LD A,(SnakeLength)
        LD B,A
        LD A,(HeadPtr)
        LD C,A
        LD (DrawIndex),A    ; Save starting index for head check
        
DrawSnakeLoop:
        PUSH BC
        
        ; Check if this is the head (first segment)
        LD A,(DrawIndex)
        CP C
        JR NZ,DrawBodyInit
        
        ; Draw head as yellow
        LD B,0
        LD HL,SnakeX
        ADD HL,BC
        LD D,(HL)
        LD HL,SnakeY
        ADD HL,BC
        LD E,(HL)
        LD A,D
        LD B,E
        CALL SetAttr
        LD A,INK_BLACK + PAPER_YELLOW + BRIGHT
        CALL WriteAttr
        JR DrawNext
        
DrawBodyInit:
        ; Draw body as green
        LD B,0
        LD HL,SnakeX
        ADD HL,BC
        LD D,(HL)
        
        LD HL,SnakeY
        ADD HL,BC
        LD E,(HL)
        
        LD A,D
        LD B,E
        CALL SetAttr
        LD A,INK_BLACK + PAPER_GREEN + BRIGHT
        CALL WriteAttr
        
DrawNext:
        POP BC
        INC C
        LD A,C
        AND MAX_LENGTH-1
        LD C,A
        DJNZ DrawSnakeLoop
        
        RET

; ============================================
; SET ATTRIBUTE ADDRESS
; Input: A = X, B = Y
; Output: HL = attribute address
; ============================================
SetAttr:
        ; Calculate: 0x5800 + (Y * 32) + X
        PUSH DE
        LD E,A          ; E = X
        LD D,0
        LD L,B          ; L = Y
        LD H,0
        ; HL = Y, multiply by 32
        ADD HL,HL       ; *2
        ADD HL,HL       ; *4
        ADD HL,HL       ; *8
        ADD HL,HL       ; *16
        ADD HL,HL       ; *32
        ADD HL,DE       ; + X
        LD DE,0x5800
        ADD HL,DE       ; + base
        POP DE
        RET

; ============================================
; WRITE ATTRIBUTE VALUE
; Input: A = attribute value, HL = address (from SetAttr)
; ============================================
WriteAttr:
        LD (HL),A
        RET

; ============================================
; SHOW GAME OVER SCREEN
; ============================================
ShowGameOver:
        ; Print "GAME OVER" in middle of screen
        LD A,22             ; AT control code
        RST 16
        LD A,10             ; Y position
        RST 16
        LD A,11             ; X position
        RST 16
        
        LD DE,GameOverText
        LD B,9
GameOverPrint:
        LD A,(DE)
        RST 16
        INC DE
        DJNZ GameOverPrint
        
        ; Print "PRESS SPACE"
        LD A,22
        RST 16
        LD A,12
        RST 16
        LD A,10
        RST 16
        
        LD DE,PressSpaceText
        LD B,11
PressSpacePrint:
        LD A,(DE)
        RST 16
        INC DE
        DJNZ PressSpacePrint
        
        RET

GameOverText:
        DEFB "GAME OVER"
        
PressSpaceText:
        DEFB "PRESS SPACE"

; ============================================
; VARIABLES
; ============================================
GameOver:   DEFB 0
Direction:  DEFB DIR_RIGHT
Score:      DEFW 0
SnakeLength:DEFB INITIAL_LEN
HeadPtr:    DEFB 0
TailPtr:    DEFB 0
NewHeadX:   DEFB 0
NewHeadY:   DEFB 0
FoodX:      DEFB 0
FoodY:      DEFB 0
DrawIndex:  DEFB 0

; Snake body coordinates (circular buffer)
SnakeX:     DEFS MAX_LENGTH
SnakeY:     DEFS MAX_LENGTH

        END Start
