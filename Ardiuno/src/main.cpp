#include <Arduino.h>
#include "config.h"
#include "sensors.h"
#include "motors.h"
#include "rgb_led.h"
#include "display.h"
#include "communication.h"
#include "navigation.h"

// Global variable definitions (declared as extern in config.h)
// Motor speeds optimized for Arduino Mega (0-255 range)
long motorSpeed = 80;         // Good speed for Arduino Mega
long obstacleThreshold = 20;  // Distance threshold in cm
long vacuumSpeed = 70;        // Higher speed for vacuum motor
long mopSpeed = 170;          // Good speed for mop motor
long pumpSpeed = 150;         // Good speed for pump motor

// Robot mode state
bool autoMode = false;  // Start in autonomous mode
String currentCommand = "";

// Command chunking support for BLE
ChunkBuffer chunkBuffer = {"", 0, 0, false, 0};
const unsigned long CHUNK_TIMEOUT_MS = 5000;  // 5 second timeout for chunked commands

// Motor A (Left motor) connections - First L298N
int enA = 2;   // PWM pin for motor A speed control
int in1 = 22;  // Motor A direction pin 1
int in2 = 23;  // Motor A direction pin 2

// Motor B (Right motor) connections - First L298N
int enB = 3;   // PWM pin for motor B speed control
int in3 = 24;  // Motor B direction pin 1
int in4 = 25;  // Motor B direction pin 2

// Second L298N Motor Driver for Vacuum motor only
// Vacuum Motor (Motor C) connections
int enC = 4;   // PWM pin for vacuum motor speed control
int in5 = 26;  // Vacuum motor direction pin 1
int in6 = 27;  // Vacuum motor direction pin 2

// Third L298N Motor Driver for Mop and Pump motors
// Mop Motor (Motor D) connections
int enD = 5;   // PWM pin for mop motor speed control
int in7 = 28;  // Mop motor direction pin 1
int in8 = 29;  // Mop motor direction pin 2

// Pump Motor (Motor E) connections - Third L298N
int enE = 9;    // PWM pin for pump motor speed control
int in9 = 30;   // Pump motor direction pin 1
int in10 = 31;  // Pump motor direction pin 2

// Control variables for mop, vacuum and pump
bool mopEnabled = false;
bool vacuumEnabled = false;
bool pumpEnabled = false;

// Sensor pins
int leftTrigPin = 32;
int leftEchoPin = 33;
int rightTrigPin = 34;
int rightEchoPin = 35;
int frontTrigPin = 36;
int frontEchoPin = 37;
int frontLeftTrigPin = 38;
int frontLeftEchoPin = 39;
int frontRightTrigPin = 40;
int frontRightEchoPin = 41;

// LED pin for obstacle detection
int ledPin = 13;  // Using built-in LED on Arduino Mega (Pin 13)

// HW-478 RGB LED pins (Common Cathode) - Using PWM pins
int rgbRedPin = 6;    // PWM pin for red
int rgbGreenPin = 7;  // PWM pin for green
int rgbBluePin = 8;   // PWM pin for blue
void setup() {
  // Initialize serial communication
  Serial.begin(9600);  // Arduino Mega standard baud rate

  // Initialize HM-10 Serial3 module
  Serial3.begin(9600);  // HM-10 default baud rate
  Serial.println("HM-10 Serial3 initialized at 9600 baud");

  // Initialize LCD display
  initializeLCD();

  // Set motor control pins as outputs (First L298N for movement)
  pinMode(enA, OUTPUT);
  pinMode(enB, OUTPUT);
  pinMode(in1, OUTPUT);
  pinMode(in2, OUTPUT);
  pinMode(in3, OUTPUT);
  pinMode(in4, OUTPUT);

  // Set vacuum motor control pins as outputs (Second L298N)
  pinMode(enC, OUTPUT);
  pinMode(in5, OUTPUT);
  pinMode(in6, OUTPUT);

  // Set mop and pump motor control pins as outputs (Third L298N)
  pinMode(enD, OUTPUT);
  pinMode(enE, OUTPUT);
  pinMode(in7, OUTPUT);
  pinMode(in8, OUTPUT);
  pinMode(in9, OUTPUT);
  pinMode(in10, OUTPUT);

  // Set ultrasonic sensor pins
  pinMode(leftTrigPin, OUTPUT);
  pinMode(leftEchoPin, INPUT);
  pinMode(rightTrigPin, OUTPUT);
  pinMode(rightEchoPin, INPUT);
  pinMode(frontTrigPin, OUTPUT);
  pinMode(frontEchoPin, INPUT);
  pinMode(frontLeftTrigPin, OUTPUT);
  pinMode(frontLeftEchoPin, INPUT);
  pinMode(frontRightTrigPin, OUTPUT);
  pinMode(frontRightEchoPin, INPUT);

  // Set LED pin as output
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, LOW);  // Start with LED off

  // Set RGB LED pins as outputs
  pinMode(rgbRedPin, OUTPUT);
  pinMode(rgbGreenPin, OUTPUT);
  pinMode(rgbBluePin, OUTPUT);
  rgbOff();  // Start with RGB LED off

  // Show startup sequence
  setRGBColor(255, 0, 255);  // MAGENTA - Starting up
  delay(1000);
  showSystemState();  // Show initial system state

  // Turn off motors - Initial state
  stopMotors();

  // All cleaning motors start OFF - controlled via BLE commands
  stopCleaningMotors();

  Serial.println("Arduino Mega Autonomous Cleaning Robot Started!");
  Serial.println("All motors are initially OFF");
  Serial.println(
      "Use BLE commands: V_ON/V_OFF (vacuum), M_ON/M_OFF (mop), P_ON/P_OFF "
      "(pump)");
  Serial.println("Front ultrasonic sensor for obstacle detection");
  Serial.println("RGB LED: RED=Obstacle detected, GREEN=Path clear");
  Serial.println(
      "Sensors: 5 Ultrasonic (front, left, right, front-left, front-right)");
}
// Variables for LED state management
unsigned long lastIdleTime = 0;
unsigned long idleCheckInterval = 30000;  // Check for idle every 30 seconds
bool isIdle = false;

void loop() {
  // Check for and handle chunked command timeout
  if (chunkBuffer.isActive && isChunkTimeout()) {
    Serial.println("⚠️ Chunk timeout - resetting buffer");
    resetChunkBuffer();
  }

  // Always check for BLE commands first and wait until command is processed
  String tempCommand = "";
  while (Serial3.available()) {
    char c = Serial3.read();

    // Check if this could be chunked binary data (first two bytes are chunk metadata)
    if (tempCommand.length() == 0 && (c == 0 || c == 1 || c == 2)) {
      // This might be chunked data - read the whole packet
      byte chunkData[20];
      chunkData[0] = c;
      int bytesRead = 1;

      // Read the rest of the packet
      unsigned long startTime = millis();
      while (bytesRead < 20 && (millis() - startTime < 100)) {
        if (Serial3.available()) {
          chunkData[bytesRead] = Serial3.read();
          bytesRead++;
        }
      }

      // Process chunked data
      if (processChunkedData(chunkData, bytesRead)) {
        // Complete command received and processed
        lastIdleTime = millis();
      }
      return;  // Skip regular command processing for this loop
    }

    tempCommand += c;
    delay(10);                // Small delay to allow complete command to arrive
    lastIdleTime = millis();  // Reset idle timer on command received
  }

  if (tempCommand.length() > 0) {
    Serial.println("📡 Received BLE command: " + tempCommand);
    Serial.println("📏 Command length: " + String(tempCommand.length()));
    processBLECommand(tempCommand);
    lastIdleTime = millis();  // Reset idle timer on command processed
  }

  // Check for idle state (no commands or movement for a while)
  if (!autoMode && (millis() - lastIdleTime > idleCheckInterval)) {
    if (!isIdle) {
      showIdleState();
      isIdle = true;
    }
  } else {
    isIdle = false;
  }

  // Only run autonomous navigation if in auto mode
  if (autoMode) {
    autonomousNavigation();
  }

  // delay(30);  // Fast loop for responsive control
}
