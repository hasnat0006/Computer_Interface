#ifndef MOTORS_H
#define MOTORS_H

#include <Arduino.h>

// Function declarations for motor control
void stopMotors();
void moveForward();
void moveBackward();
void turnLeft();
void turnRight();
void turn180Degrees();

// Cleaning motor function declarations
void startMop();
void stopMop();
void startVacuum();
void stopVacuum();
void startPump();
void stopPump();
void toggleMop();
void toggleVacuum();
void togglePump();
void stopCleaningMotors();

#endif
