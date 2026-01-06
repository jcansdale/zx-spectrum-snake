/*
 * Snake Game for ZX Spectrum
 * Compile with z88dk: zcc +zx -vn -startup=1 -clib=sdcc_iy snake.c -o snake_c -create-app
 */

#include <arch/zx.h>
#include <input.h>
#include <z80.h>
#include <stdlib.h>
#include <string.h>
#include <intrinsic.h>

// Game constants
#define MAX_LENGTH 128
#define INITIAL_LENGTH 5
#define GAME_SPEED 80

// Screen boundaries (play area)
#define MIN_X 1
#define MAX_X 30
#define MIN_Y 1
#define MAX_Y 22

// Directions
#define DIR_UP 0
#define DIR_DOWN 1
#define DIR_LEFT 2
#define DIR_RIGHT 3

// Game state
unsigned char snakeX[MAX_LENGTH];
unsigned char snakeY[MAX_LENGTH];
unsigned char headPtr;
unsigned char tailPtr;
unsigned char snakeLength;
unsigned char direction;
unsigned char newHeadX, newHeadY;
unsigned char foodX, foodY;
unsigned int score;
unsigned char gameOver;

// Pointer to attribute memory
#define ATTR_BASE ((unsigned char *)0x5800)

// Set attribute at character position
void setAttr(unsigned char x, unsigned char y, unsigned char attr) {
    ATTR_BASE[y * 32 + x] = attr;
}

// Get attribute at character position
unsigned char getAttr(unsigned char x, unsigned char y) {
    return ATTR_BASE[y * 32 + x];
}

// Clear screen to black
void clearScreen(void) {
    // Clear pixel data
    memset((void *)0x4000, 0, 6144);
    // Clear attributes to black
    memset((void *)0x5800, 0, 768);
}

// Delay loop
void delay(unsigned int ms) {
    for (unsigned int i = 0; i < ms; i++) {
        for (volatile unsigned char j = 0; j < 200; j++) {
            // Busy wait
        }
    }
}

// Draw rainbow border
void drawBorder(void) {
    unsigned char colors[] = {PAPER_RED, PAPER_YELLOW, PAPER_GREEN, PAPER_CYAN, PAPER_BLUE, PAPER_MAGENTA};
    unsigned char colorIdx = 0;
    
    // Top border (row 0)
    for (unsigned char x = 0; x < 32; x++) {
        setAttr(x, 0, colors[colorIdx % 6] | BRIGHT);
        colorIdx++;
    }
    
    // Bottom border (row 23)
    colorIdx = 0;
    for (unsigned char x = 0; x < 32; x++) {
        setAttr(x, 23, colors[colorIdx % 6] | BRIGHT);
        colorIdx++;
    }
    
    // Left border (rows 0-23)
    colorIdx = 0;
    for (unsigned char y = 0; y < 24; y++) {
        setAttr(0, y, colors[colorIdx % 6] | BRIGHT);
        colorIdx++;
    }
    
    // Right border (rows 0-23)
    colorIdx = 0;
    for (unsigned char y = 0; y < 24; y++) {
        setAttr(31, y, colors[colorIdx % 6] | BRIGHT);
        colorIdx++;
    }
}

// Draw food (red)
void drawFood(void) {
    setAttr(foodX, foodY, INK_BLACK | PAPER_RED | BRIGHT);
}

// Place food at random location
void placeFood(void) {
    unsigned char valid;
    unsigned char idx;
    
    do {
        valid = 1;
        foodX = (rand() % (MAX_X - MIN_X)) + MIN_X;
        foodY = (rand() % (MAX_Y - MIN_Y)) + MIN_Y;
        
        // Check not on snake
        idx = tailPtr;
        for (unsigned char i = 0; i < snakeLength; i++) {
            if (snakeX[idx] == foodX && snakeY[idx] == foodY) {
                valid = 0;
                break;
            }
            idx = (idx + 1) & (MAX_LENGTH - 1);
        }
    } while (!valid);
    
    drawFood();
}

// Draw entire snake
void drawSnake(void) {
    unsigned char idx = tailPtr;
    
    for (unsigned char i = 0; i < snakeLength; i++) {
        unsigned char x = snakeX[idx];
        unsigned char y = snakeY[idx];
        
        if (idx == headPtr) {
            // Head is yellow
            setAttr(x, y, INK_BLACK | PAPER_YELLOW | BRIGHT);
        } else {
            // Body is green
            setAttr(x, y, INK_BLACK | PAPER_GREEN | BRIGHT);
        }
        
        idx = (idx + 1) & (MAX_LENGTH - 1);
    }
}

// Initialize game state
void initGame(void) {
    unsigned char i;
    
    clearScreen();
    
    score = 0;
    snakeLength = INITIAL_LENGTH;
    headPtr = INITIAL_LENGTH - 1;
    tailPtr = 0;
    direction = DIR_RIGHT;
    gameOver = 0;
    
    // Initialize snake in middle of screen
    for (i = 0; i < INITIAL_LENGTH; i++) {
        snakeX[i] = 10 + i;
        snakeY[i] = 11;
    }
    
    drawBorder();
    placeFood();
    drawSnake();
}

// Check keyboard input using direct port reading
void checkInput(void) {
    unsigned char keys;
    
    // Row Q-T (port 0xFBFE)
    keys = z80_inp(0xFBFE);
    if (!(keys & 0x01) && direction != DIR_DOWN) {  // Q
        direction = DIR_UP;
        return;
    }
    
    // Row A-G (port 0xFDFE)
    keys = z80_inp(0xFDFE);
    if (!(keys & 0x01) && direction != DIR_UP) {    // A
        direction = DIR_DOWN;
        return;
    }
    
    // Row Y-P (port 0xDFFE)
    keys = z80_inp(0xDFFE);
    if (!(keys & 0x02) && direction != DIR_RIGHT) { // O
        direction = DIR_LEFT;
        return;
    }
    if (!(keys & 0x01) && direction != DIR_LEFT) {  // P
        direction = DIR_RIGHT;
        return;
    }
}

// Check collision - returns 1 if collision
unsigned char checkCollision(void) {
    unsigned char idx;
    unsigned char i;
    
    // Wall collision
    if (newHeadX < MIN_X || newHeadX > MAX_X ||
        newHeadY < MIN_Y || newHeadY > MAX_Y) {
        return 1;
    }
    
    // Self collision - check against body (skip tail, it will move)
    idx = (tailPtr + 1) & (MAX_LENGTH - 1);
    for (i = 1; i < snakeLength; i++) {
        if (snakeX[idx] == newHeadX && snakeY[idx] == newHeadY) {
            return 1;
        }
        idx = (idx + 1) & (MAX_LENGTH - 1);
    }
    
    return 0;
}

// Move snake
void moveSnake(void) {
    unsigned char oldHeadX, oldHeadY;
    unsigned char ateFood;
    
    // Calculate new head position
    oldHeadX = snakeX[headPtr];
    oldHeadY = snakeY[headPtr];
    
    newHeadX = oldHeadX;
    newHeadY = oldHeadY;
    
    switch (direction) {
        case DIR_UP:    newHeadY--; break;
        case DIR_DOWN:  newHeadY++; break;
        case DIR_LEFT:  newHeadX--; break;
        case DIR_RIGHT: newHeadX++; break;
    }
    
    // Check collision
    if (checkCollision()) {
        gameOver = 1;
        return;
    }
    
    // Check if eating food
    ateFood = (newHeadX == foodX && newHeadY == foodY);
    
    if (!ateFood) {
        // Erase tail
        setAttr(snakeX[tailPtr], snakeY[tailPtr], 0);
        tailPtr = (tailPtr + 1) & (MAX_LENGTH - 1);
    } else {
        // Grow snake
        if (snakeLength < MAX_LENGTH - 1) {
            snakeLength++;
        }
        score += 10;
        placeFood();
    }
    
    // Change old head to body color
    setAttr(oldHeadX, oldHeadY, INK_BLACK | PAPER_GREEN | BRIGHT);
    
    // Add new head
    headPtr = (headPtr + 1) & (MAX_LENGTH - 1);
    snakeX[headPtr] = newHeadX;
    snakeY[headPtr] = newHeadY;
    
    // Draw new head
    setAttr(newHeadX, newHeadY, INK_BLACK | PAPER_YELLOW | BRIGHT);
}

// Game over screen
void gameOverScreen(void) {
    unsigned char i, x;
    
    // Flash border
    for (i = 0; i < 20; i++) {
        zx_border(2);  // Red
        delay(50);
        zx_border(0);  // Black
        delay(50);
    }
    
    // Set game over text area to red
    for (x = 10; x < 22; x++) {
        setAttr(x, 10, INK_WHITE | PAPER_RED | BRIGHT);
        setAttr(x, 11, INK_WHITE | PAPER_RED | BRIGHT);
        setAttr(x, 12, INK_WHITE | PAPER_RED | BRIGHT);
    }
}

// Wait for any key
void waitKey(void) {
    // Wait for all keys released
    while (z80_inp(0xFEFE) != 0xFF || z80_inp(0xFDFE) != 0xFF ||
           z80_inp(0xFBFE) != 0xFF || z80_inp(0xF7FE) != 0xFF ||
           z80_inp(0xEFFE) != 0xFF || z80_inp(0xDFFE) != 0xFF ||
           z80_inp(0xBFFE) != 0xFF || z80_inp(0x7FFE) != 0xFF) {
        // Wait
    }
    
    // Wait for any key pressed
    while (z80_inp(0xFEFE) == 0xFF && z80_inp(0xFDFE) == 0xFF &&
           z80_inp(0xFBFE) == 0xFF && z80_inp(0xF7FE) == 0xFF &&
           z80_inp(0xEFFE) == 0xFF && z80_inp(0xDFFE) == 0xFF &&
           z80_inp(0xBFFE) == 0xFF && z80_inp(0x7FFE) == 0xFF) {
        // Wait
    }
}

// Main function
void main(void) {
    // Seed random number generator with R register
    srand(z80_inp(0xFEFE) ^ 12345);
    
    // Set border black
    zx_border(0);
    
    while (1) {
        initGame();
        
        // Main game loop
        while (!gameOver) {
            checkInput();
            moveSnake();
            delay(GAME_SPEED);
        }
        
        gameOverScreen();
        waitKey();
    }
}
