#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// Motor speeds optimized for Arduino Mega (0-255 range)
extern long motorSpeed;         // Good speed for Arduino Mega
extern long obstacleThreshold;  // Distance threshold in cm
extern long vacuumSpeed;        // Higher speed for vacuum motor
extern long mopSpeed;           // Good speed for mop motor
extern long pumpSpeed;          // Good speed for pump motor

// Robot mode state
extern bool autoMode;  // Start in autonomous mode
extern String currentCommand;

// Motor A (Left motor) connections - First L298N
extern int enA;   // PWM pin for motor A speed control
extern int in1;   // Motor A direction pin 1
extern int in2;   // Motor A direction pin 2

// Motor B (Right motor) connections - First L298N
extern int enB;   // PWM pin for motor B speed control
extern int in3;   // Motor B direction pin 1
extern int in4;   // Motor B direction pin 2

// Second L298N Motor Driver for Vacuum motor only
// Vacuum Motor (Motor C) connections
extern int enC;   // PWM pin for vacuum motor speed control
extern int in5;   // Vacuum motor direction pin 1
extern int in6;   // Vacuum motor direction pin 2

// Third L298N Motor Driver for Mop and Pump motors
// Mop Motor (Motor D) connections
extern int enD;   // PWM pin for mop motor speed control
extern int in7;   // Mop motor direction pin 1
extern int in8;   // Mop motor direction pin 2

// Pump Motor (Motor E) connections - Third L298N
extern int enE;    // PWM pin for pump motor speed control
extern int in9;    // Pump motor direction pin 1
extern int in10;   // Pump motor direction pin 2

// Control variables for mop, vacuum and pump
extern bool mopEnabled;
extern bool vacuumEnabled;
extern bool pumpEnabled;

// Sensor pins
extern int leftTrigPin;
extern int leftEchoPin;
extern int rightTrigPin;
extern int rightEchoPin;
extern int frontTrigPin;
extern int frontEchoPin;
extern int frontLeftTrigPin;
extern int frontLeftEchoPin;
extern int frontRightTrigPin;
extern int frontRightEchoPin;

// LED pin for obstacle detection
extern int ledPin;

// HW-478 RGB LED pins (Common Cathode) - Using PWM pins
extern int rgbRedPin;    // PWM pin for red
extern int rgbGreenPin;  // PWM pin for green
extern int rgbBluePin;   // PWM pin for blue

// Command chunking support for BLE
struct ChunkBuffer {
  String data;
  int currentChunk;
  int totalChunks;
  bool isActive;
  unsigned long lastChunkTime;
};

extern ChunkBuffer chunkBuffer;
extern const unsigned long CHUNK_TIMEOUT_MS;

#endif
