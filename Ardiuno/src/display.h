#ifndef DISPLAY_H
#define DISPLAY_H

#include <Arduino.h>
#include <LiquidCrystal_I2C.h>

// LCD Display object (external declaration)
extern LiquidCrystal_I2C lcd;

// Function declarations for display operations
void initializeLCD();
void updateLCD(String status, long leftDist, long rightDist, long frontDist,
               long frontLeftDist, long frontRightDist);

#endif
