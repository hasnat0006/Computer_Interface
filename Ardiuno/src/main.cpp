#include <Arduino.h>
#include <ArduinoJson.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

LiquidCrystal_I2C lcd(0x27, 16, 2);

// Motor speeds optimized for Arduino Mega (0-255 range)
long motorSpeed = 80;         // Good speed for Arduino Mega
long obstacleThreshold = 20;  // Distance threshold in cm
long vacuumSpeed = 70;        // Higher speed for vacuum motor
long mopSpeed = 170;          // Good speed for mop motor
long pumpSpeed = 150;         // Good speed for pump motor

// I2C LCD (address 0x27, 16x2 display)
// Arduino Mega I2C pins: SDA = Pin 20, SCL = Pin 21

// HM-10 BLE Module pins (using pins 0, 1 to avoid conflict with other pins)
// SoftwareSerial Serial3(0, 1);  // RX=0, TX=1

// Robot mode state
bool autoMode = false;  // Start in autonomous mode
String currentCommand = "";

// Command chunking support for BLE
struct ChunkBuffer {
  String data;
  int currentChunk;
  int totalChunks;
  bool isActive;
  unsigned long lastChunkTime;
} chunkBuffer = {"", 0, 0, false, 0};

const unsigned long CHUNK_TIMEOUT_MS =
    5000;  // 5 second timeout for chunked commands

// Motor A (Left motor) connections - First L298N
int enA = 2;   // PWM pin for motor A speed control (Pin 2 - PWM capable).
int in1 = 22;  // Motor A direction pin 1
int in2 = 23;  // Motor A direction pin 2

// Motor B (Right motor) connections - First L298N
int enB = 3;   // PWM pin for motor B speed control (Pin 3 - PWM capable)
int in3 = 24;  // Motor B direction pin 1
int in4 = 25;  // Motor B direction pin 2

// Second L298N Motor Driver for Vacuum motor only
// Vacuum Motor (Motor C) connections
int enC = 4;   // PWM pin for vacuum motor speed control (Pin 4 - PWM capable)
int in5 = 26;  // Vacuum motor direction pin 1
int in6 = 27;  // Vacuum motor direction pin 2

// Third L298N Motor Driver for Mop and Pump motors
// Mop Motor (Motor D) connections
int enD = 5;   // PWM pin for mop motor speed control (Pin 5 - PWM capable)
int in7 = 28;  // Mop motor direction pin 1
int in8 = 29;  // Mop motor direction pin 2

// Pump Motor (Motor E) connections - Third L298N
int enE = 9;    // PWM pin for pump motor speed control (Pin 9 - PWM capable)
int in9 = 30;   // Pump motor direction pin 1
int in10 = 31;  // Pump motor direction pin 2

// Control variables for mop, vacuum and pump
bool mopEnabled = false;
bool vacuumEnabled = false;
bool pumpEnabled = false;

// Sensor pins - Using abundant Arduino Mega pins
// Left ultrasonic sensor
int leftTrigPin = 32;
int leftEchoPin = 33;
// Right ultrasonic sensor
int rightTrigPin = 34;
int rightEchoPin = 35;
// Front ultrasonic sensor (replaces IR sensor)
int frontTrigPin = 36;  // Trig pin for front ultrasonic sensor
int frontEchoPin = 37;  // Echo pin for front ultrasonic sensor
// Front-left ultrasonic sensor
int frontLeftTrigPin = 38;
int frontLeftEchoPin = 39;
// Front-right ultrasonic sensor
int frontRightTrigPin = 40;
int frontRightEchoPin = 41;

// LED pin for obstacle detection
int ledPin = 13;  // Using built-in LED on Arduino Mega (Pin 13)

// HW-478 RGB LED pins (Common Cathode) - Using PWM pins
int rgbRedPin = 6;    // PWM pin for red
int rgbGreenPin = 7;  // PWM pin for green
int rgbBluePin = 8;   // PWM pin for blue

// Function declarations
void stopMotors();
long getDistance(int trigPin, int echoPin);
void moveForward();
void moveBackward();
void turnLeft();
void turnRight();
void avoidObstacle();
void updateLCD(String status, long leftDist, long rightDist, long frontDist,
               long frontLeftDist, long frontRightDist);

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

// RGB LED function declarations
void setRGBColor(int red, int green, int blue);
void showObstacleDirection(bool leftObstacle, bool frontLeftObstacle,
                           bool frontObstacle, bool frontRightObstacle,
                           bool rightObstacle);
void rgbOff();
void blinkGreenLED();
void showSystemState();
void showBatteryState();
void showErrorState();
void showIdleState();
void pulseBlue();

// JSON processing function declarations
void processShortJsonCommand(StaticJsonDocument<1024> &doc, String action);
void processLongJsonCommand(StaticJsonDocument<1024> &doc, String action);

// Chunking support function declarations
bool processChunkedData(byte *data, int length);
void resetChunkBuffer();
bool isChunkTimeout();

// 180-degree turn function
void turn180Degrees();

// JSON command processing
void processJsonCommand(String jsonString);
bool isValidJson(String jsonString);
void handleMoveCommand(String direction);
void sendStatusResponse();

// Process BLE commands from the mobile app
void processBLECommand(String command) {
  Serial.println("🔄 Processing BLE Command: " + command);
  Serial.println("📏 Command Length: " + String(command.length()) + " chars");

  // Check if the command is in JSON format
  if (isValidJson(command)) {
    Serial.println("✅ Valid JSON detected - processing JSON command");
    processJsonCommand(command);
    return;
  }

  // Legacy command processing (uppercase)
  command.toUpperCase();
  currentCommand = command;
  Serial.println("🔤 Processing legacy command: '" + command + "'");
  Serial3.println("ACK:" + command);

  if (command == "HELLO ARDUINO") {
    Serial.println("✅ Hello Arduino received!");
    Serial3.println("Hello Flutter App!");
  } else if (command == "TEST") {
    Serial.println("✅ Connection test successful!");
    Serial3.println("TEST_OK");
  } else if (command == "V_ON") {
    startVacuum();
    showSystemState();  // Update LED to show cleaning active
    Serial3.println("VACUUM_ON");
  } else if (command == "V_OFF") {
    stopVacuum();
    showSystemState();  // Update LED to show cleaning inactive
    Serial3.println("VACUUM_OFF");
  } else if (command == "M_ON") {
    startMop();
    showSystemState();  // Update LED to show cleaning active
    Serial3.println("MOP_ON");
  } else if (command == "M_OFF") {
    stopMop();
    showSystemState();  // Update LED to show cleaning inactive
    Serial3.println("MOP_OFF");
  } else if (command == "P_ON") {
    startPump();
    showSystemState();  // Update LED to show cleaning active
    Serial3.println("PUMP_ON");
  } else if (command == "P_OFF") {
    stopPump();
    showSystemState();  // Update LED to show cleaning inactive
    Serial3.println("PUMP_OFF");
  } else if (command == "AUTO") {
    autoMode = true;
    showSystemState();  // Update LED for auto mode
    Serial.println("✅ Autonomous mode activated");
    Serial3.println("AUTO_MODE_ON");
  } else if (command == "MANUAL") {
    autoMode = false;
    stopMotors();
    showSystemState();  // Update LED for manual mode
    Serial.println("✅ Manual mode activated");
    Serial3.println("MANUAL_MODE_ON");
  } else if (command == "F" && !autoMode) {
    moveForward();
    Serial.println("✅ Moving forward");
    Serial3.println("MOVING_FORWARD");
  } else if (command == "B" && !autoMode) {
    moveBackward();
    Serial.println("✅ Moving backward");
    Serial3.println("MOVING_BACKWARD");
  } else if (command == "L" && !autoMode) {
    turnLeft();
    Serial.println("✅ Turning left");
    Serial3.println("TURNING_LEFT");
  } else if (command == "R" && !autoMode) {
    turnRight();
    Serial.println("✅ Turning right");
    Serial3.println("TURNING_RIGHT");
  } else if (command == "S") {
    stopMotors();
    Serial.println("✅ Stopped");
    Serial3.println("STOPPED");
  } else if (command == "LED") {
    blinkGreenLED();
    Serial.println("✅ LED command - Green blink");
    Serial3.println("LED_BLINK_GREEN");
  } else if (command == "PULSE") {
    pulseBlue();
    Serial.println("✅ Blue pulse effect");
    Serial3.println("PULSE_EFFECT");
  } else if (command == "STATUS") {
    showSystemState();
    Serial.println("✅ System status display");
    Serial3.println("STATUS_DISPLAY");
  } else {
    Serial.println("❌ Unknown command: " + command);
    Serial3.println("UNKNOWN_COMMAND:" + command);
  }
}

// JSON command processing functions
bool isValidJson(String jsonString) {
  StaticJsonDocument<1024> doc;
  DeserializationError error = deserializeJson(doc, jsonString);
  return error == DeserializationError::Ok;
}

void processJsonCommand(String jsonString) {
  Serial.println("🔍 Processing JSON command...");
  Serial.println("📄 JSON String: " + jsonString);

  StaticJsonDocument<1024> doc;
  DeserializationError error = deserializeJson(doc, jsonString);

  if (error) {
    Serial.println("❌ JSON parsing failed: " + String(error.c_str()));
    return;
  }

  // Check if this is a short format command (uses "a" instead of "action")
  bool isShortFormat = doc.containsKey("a");
  String action =
      isShortFormat ? doc["a"].as<String>() : doc["action"].as<String>();

  Serial.println("📋 JSON Action: " + action +
                 " (Format: " + (isShortFormat ? "SHORT" : "LONG") + ")");

  // Handle short format commands
  if (isShortFormat) {
    processShortJsonCommand(doc, action);
  } else {
    // Handle original long format commands
    processLongJsonCommand(doc, action);
  }
}

// Process short format JSON commands
void processShortJsonCommand(StaticJsonDocument<1024> &doc, String action) {
  // Movement commands: {"a":"mv","d":"f"}
  if (action == "mv") {
    String direction = doc["d"].as<String>();
    handleMoveCommand(direction);

    // Component control commands: {"a":"v","s":1}
  } else if (action == "v") {
    int state = doc["s"].as<int>();
    if (state == 1) {
      startVacuum();
      Serial.println("Vacuum ON (short)");
    } else {
      stopVacuum();
      Serial.println("Vacuum OFF (short)");
    }
    showSystemState();
  } else if (action == "mp") {  // Mop command
    int state = doc["s"].as<int>();
    if (state == 1) {
      startMop();
      Serial.println("Mop ON (short)");
    } else {
      stopMop();
      Serial.println("Mop OFF (short)");
    }
    showSystemState();
  } else if (action == "p") {
    int state = doc["s"].as<int>();
    if (state == 1) {
      startPump();
      Serial.println("Pump ON (short)");
    } else {
      stopPump();
      Serial.println("Pump OFF (short)");
    }
    showSystemState();

    // Mode commands: {"a":"o","t":"a"}
  } else if (action == "o") {
    String type = doc["t"].as<String>();
    if (type == "a") {
      autoMode = true;
      Serial.println("✅ Autonomous mode activated (short)");
    } else if (type == "m") {
      autoMode = false;
      stopMotors();
      Serial.println("✅ Manual mode activated (short)");
    }
    showSystemState();

    // Multi-component commands: {"a":"mu","d":"f","v":1,"m":0,"p":0}
  } else if (action == "mu") {
    String direction = doc["d"].as<String>();
    int v = doc["v"].as<int>();
    int m = doc["m"].as<int>();
    int p = doc["p"].as<int>();

    // Handle movement
    if (direction.length() > 0) {
      handleMoveCommand(direction);
    }

    // Handle components
    if (doc.containsKey("v")) {
      if (v == 1)
        startVacuum();
      else
        stopVacuum();
    }
    if (doc.containsKey("m")) {
      if (m == 1)
        startMop();
      else
        stopMop();
    }
    if (doc.containsKey("p")) {
      if (p == 1)
        startPump();
      else
        stopPump();
    }

    Serial.println("Multi-command executed (short): " + direction +
                   " v:" + String(v) + " m:" + String(m) + " p:" + String(p));
    showSystemState();

    // Status commands: {"a":"s"}
  } else if (action == "s") {
    sendStatusResponse();

    // Emergency command: {"a":"e"}
  } else if (action == "e") {
    stopMotors();
    stopCleaningMotors();
    Serial.println("🚨 EMERGENCY STOP (short)");
    showErrorState();

    // Test command: {"a":"t","c":"led"}
  } else if (action == "t") {
    String component = doc["c"].as<String>();
    if (component == "led") {
      blinkGreenLED();
      Serial.println("✅ LED test executed (short)");
    }
  } else {
    Serial.println("❌ Unknown short command: " + action);
  }
}

// Process original long format JSON commands
void processLongJsonCommand(StaticJsonDocument<1024> &doc, String action) {
  // Movement commands
  if (action == "move") {
    String direction = doc["direction"].as<String>();
    handleMoveCommand(direction);

    // Component control commands
  } else if (action == "v") {
    int state = doc["state"].as<int>();
    if (state == 1) {
      startVacuum();
      Serial.println("Vacuum ON");
    } else {
      stopVacuum();
      Serial.println("Vacuum OFF");
    }
    showSystemState();
  } else if (action == "m") {
    int state = doc["state"].as<int>();
    if (state == 1) {
      startMop();
      Serial.println("Mop ON");
    } else {
      stopMop();
      Serial.println("Mop OFF");
    }
    showSystemState();
  } else if (action == "p") {
    int state = doc["state"].as<int>();
    if (state == 1) {
      startPump();
      Serial.println("Pump ON");
    } else {
      stopPump();
      Serial.println("Pump OFF");
    }
    showSystemState();

    // Mode commands
  } else if (action == "mode") {
    String type = doc["type"].as<String>();
    if (type == "auto") {
      autoMode = true;
      Serial.println("✅ Autonomous mode activated");
    } else if (type == "man") {
      autoMode = false;
      stopMotors();
      Serial.println("✅ Manual mode activated");
    }
    showSystemState();

    // Multi-component commands
  } else if (action == "multi") {
    String direction = doc["direction"].as<String>();
    int v = doc["v"].as<int>();
    int m = doc["m"].as<int>();
    int p = doc["p"].as<int>();

    // Handle movement
    if (direction.length() > 0) {
      handleMoveCommand(direction);
    }

    // Handle components
    if (v == 1)
      startVacuum();
    else
      stopVacuum();
    if (m == 1)
      startMop();
    else
      stopMop();
    if (p == 1)
      startPump();
    else
      stopPump();

    Serial.println("Multi-command executed: " + direction + " v:" + String(v) +
                   " m:" + String(m) + " p:" + String(p));
    showSystemState();

    // Status commands
  } else if (action == "status") {
    sendStatusResponse();
  } else if (action == "emergency") {
    stopMotors();
    stopCleaningMotors();
    Serial.println("🚨 EMERGENCY STOP");
    showErrorState();
  } else if (action == "test") {
    String component = doc["component"].as<String>();
    if (component == "led") {
      blinkGreenLED();
      Serial.println("✅ LED test executed");
    }
  } else {
    Serial.println("❌ Unknown long command: " + action);
  }
}

void handleMoveCommand(String direction) {
  if (!autoMode) {  // Only allow manual movement in manual mode
    if (direction == "f") {
      moveForward();
      Serial.println("Move command executed: forward");
    } else if (direction == "b") {
      moveBackward();
      Serial.println("Move command executed: backward");
    } else if (direction == "l") {
      turnLeft();
      Serial.println("Move command executed: left");
    } else if (direction == "r") {
      turnRight();
      Serial.println("Move command executed: right");
    } else if (direction == "s") {
      stopMotors();
      Serial.println("Move command executed: stop");
    }
  } else {
    Serial.println("⚠️ Movement ignored - Robot in autonomous mode");
  }
}

void sendStatusResponse() {
  Serial.println("=== ROBOT STATUS ===");
  Serial.println("Mode: " + String(autoMode ? "Autonomous" : "Manual"));
  Serial.println("Vacuum: " + String(vacuumEnabled ? "ON" : "OFF"));
  Serial.println("Mop: " + String(mopEnabled ? "ON" : "OFF"));
  Serial.println("Pump: " + String(pumpEnabled ? "ON" : "OFF"));
  Serial.println("===================");
}

void setup() {
  // Initialize serial communication
  Serial.begin(9600);  // Arduino Mega standard baud rate

  // Initialize HM-10 Serial3 module
  Serial3.begin(9600);  // HM-10 default baud rate
  Serial.println("HM-10 Serial3 initialized at 9600 baud");

  // Initialize I2C communication for LCD (Arduino Mega: SDA=20, SCL=21)
  Wire.begin();

  // Initialize I2C LCD
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Arduino Mega");
  lcd.setCursor(0, 1);
  lcd.print("Robot Starting..");
  delay(2000);

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
  stopMop();
  stopVacuum();
  stopPump();

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

long getDistance(int trigPin, int echoPin) {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH);
  int distance = duration * 0.034 / 2;  // Convert to cm
  return distance;
}

// Front ultrasonic sensor reading function
bool getFrontIRObstacle() {
  long distance = getDistance(frontTrigPin, frontEchoPin);
  // Return true if obstacle is detected (distance less than threshold)
  return distance < obstacleThreshold;
}

// Get front distance for ultrasonic sensor (for LCD display)
long getFrontDistance() { return getDistance(frontTrigPin, frontEchoPin); }

void stopMotors() {
  // Stop main drive motors (First L298N)
  digitalWrite(in1, LOW);
  digitalWrite(in2, LOW);
  digitalWrite(in3, LOW);
  digitalWrite(in4, LOW);
  analogWrite(enA, 0);
  analogWrite(enB, 0);

  // Restore full cleaning motor speeds when not driving
  if (vacuumEnabled) {
    analogWrite(enC, vacuumSpeed);  // Restore vacuum speed (Second L298N)
  }
  if (mopEnabled) {
    analogWrite(enD, mopSpeed);  // Restore mop speed (Third L298N)
  }
  if (pumpEnabled) {
    analogWrite(enE, pumpSpeed);  // Restore pump speed (Third L298N)
  }
}

// Motor control functions with power management
void moveForward() {
  // Reduce cleaning motor speeds when driving to save power
  if (vacuumEnabled) {
    analogWrite(
        enC, vacuumSpeed * 0.8);  // Reduce vacuum speed to 80% (Second L298N)
  }
  if (mopEnabled) {
    analogWrite(enD, mopSpeed * 0.7);  // Reduce mop speed to 70% (Third L298N)
  }
  if (pumpEnabled) {
    analogWrite(enE,
                pumpSpeed * 0.7);  // Reduce pump speed to 70% (Third L298N)
  }

  analogWrite(enA, motorSpeed);
  analogWrite(enB, motorSpeed);
  digitalWrite(in1, LOW);
  digitalWrite(in2, HIGH);
  digitalWrite(in3, LOW);
  digitalWrite(in4, HIGH);
}

void moveBackward() {
  // Reduce cleaning motor speeds when driving to save power
  if (vacuumEnabled) {
    analogWrite(
        enC, vacuumSpeed * 0.8);  // Reduce vacuum speed to 80% (Second L298N)
  }
  if (mopEnabled) {
    analogWrite(enD, mopSpeed * 0.7);  // Reduce mop speed to 70% (Third L298N)
  }
  if (pumpEnabled) {
    analogWrite(enE,
                pumpSpeed * 0.7);  // Reduce pump speed to 70% (Third L298N)
  }

  analogWrite(enA, motorSpeed);
  analogWrite(enB, motorSpeed);
  digitalWrite(in1, HIGH);
  digitalWrite(in2, LOW);
  digitalWrite(in3, HIGH);
  digitalWrite(in4, LOW);
}

void turnLeft() {
  // Reduce cleaning motor speeds when turning to save power
  if (vacuumEnabled) {
    analogWrite(
        enC, vacuumSpeed * 0.7);  // Reduce vacuum speed to 70% (Second L298N)
  }
  if (mopEnabled) {
    analogWrite(enD, mopSpeed * 0.6);  // Reduce mop speed to 60% (Third L298N)
  }
  if (pumpEnabled) {
    analogWrite(enE,
                pumpSpeed * 0.6);  // Reduce pump speed to 60% (Third L298N)
  }

  analogWrite(enA, motorSpeed);
  analogWrite(enB, motorSpeed);
  // SWAPPED: Left motor backward, right motor forward (to turn left)
  digitalWrite(in1, HIGH);
  digitalWrite(in2, LOW);
  digitalWrite(in3, LOW);
  digitalWrite(in4, HIGH);
}

void turnRight() {
  // Reduce cleaning motor speeds when turning to save power
  if (vacuumEnabled) {
    analogWrite(
        enC, vacuumSpeed * 0.7);  // Reduce vacuum speed to 70% (Second L298N)
  }
  if (mopEnabled) {
    analogWrite(enD, mopSpeed * 0.6);  // Reduce mop speed to 60% (Third L298N)
  }
  if (pumpEnabled) {
    analogWrite(enE,
                pumpSpeed * 0.6);  // Reduce pump speed to 60% (Third L298N)
  }

  analogWrite(enA, motorSpeed);
  analogWrite(enB, motorSpeed);
  // SWAPPED: Left motor forward, right motor backward (to turn right)
  digitalWrite(in1, LOW);
  digitalWrite(in2, HIGH);
  digitalWrite(in3, HIGH);
  digitalWrite(in4, LOW);
}

// Cleaning Motor Control Functions
void startVacuum() {
  analogWrite(enC, vacuumSpeed);  // Second L298N - Motor C is now vacuum
  digitalWrite(in5, HIGH);
  digitalWrite(in6, LOW);
  vacuumEnabled = true;
  Serial.println("Vacuum motor started");
}

void stopVacuum() {
  analogWrite(enC, 0);  // Second L298N - Motor C is now vacuum
  digitalWrite(in5, LOW);
  digitalWrite(in6, LOW);
  vacuumEnabled = false;
  Serial.println("Vacuum motor stopped");
}

void startMop() {
  analogWrite(enD, mopSpeed);  // Third L298N - Motor D is now mop
  digitalWrite(in7, HIGH);
  digitalWrite(in8, LOW);
  mopEnabled = true;
  Serial.println("Mop motor started");
}

void stopMop() {
  analogWrite(enD, 0);  // Third L298N - Motor D is now mop
  digitalWrite(in7, LOW);
  digitalWrite(in8, LOW);
  mopEnabled = false;
  Serial.println("Mop motor stopped");
}

void startPump() {
  analogWrite(enE, pumpSpeed);  // Third L298N - Motor E is pump
  digitalWrite(in9, HIGH);
  digitalWrite(in10, LOW);
  pumpEnabled = true;
  Serial.println("Pump motor started");
}

void stopPump() {
  analogWrite(enE, 0);  // Third L298N - Motor E is pump
  digitalWrite(in9, LOW);
  digitalWrite(in10, LOW);
  pumpEnabled = false;
  Serial.println("Pump motor stopped");
}

void toggleVacuum() {
  if (vacuumEnabled) {
    stopVacuum();
  } else {
    startVacuum();
  }
}

void toggleMop() {
  if (mopEnabled) {
    stopMop();
  } else {
    startMop();
  }
}

void togglePump() {
  if (pumpEnabled) {
    stopPump();
  } else {
    startPump();
  }
}

void stopCleaningMotors() {
  stopMop();
  stopVacuum();
  stopPump();
  Serial.println("All cleaning motors stopped");
}

// RGB LED Control Functions for HW-478 Module
void setRGBColor(int red, int green, int blue) {
  // HW-478 is typically Common Cathode, so HIGH = ON
  // Values: 0-255 for PWM control (0 = off, 255 = full brightness)
  analogWrite(rgbRedPin, red);
  analogWrite(rgbGreenPin, green);
  analogWrite(rgbBluePin, blue);
}

void rgbOff() { setRGBColor(0, 0, 0); }

// LED command - Blink green for 2-3 seconds
void blinkGreenLED() {
  unsigned long startTime = millis();
  unsigned long blinkDuration = 2500;  // 2.5 seconds

  while (millis() - startTime < blinkDuration) {
    setRGBColor(0, 255, 0);  // Green ON
    delay(200);
    rgbOff();  // Green OFF
    delay(200);
  }

  // Return to system state after blinking
  showSystemState();
}

// Show different system states with colors
void showSystemState() {
  if (autoMode) {
    if (vacuumEnabled || mopEnabled || pumpEnabled) {
      setRGBColor(0, 255, 255);  // CYAN - Auto mode with cleaning active
    } else {
      setRGBColor(0, 0, 255);  // BLUE - Auto mode idle
    }
  } else {
    if (vacuumEnabled || mopEnabled || pumpEnabled) {
      setRGBColor(255, 165, 0);  // ORANGE - Manual mode with cleaning active
    } else {
      setRGBColor(128, 0, 128);  // PURPLE - Manual mode idle
    }
  }
}

// Show battery/power state (simulated)
void showBatteryState() {
  // Simulate battery levels with different colors
  // Green = Good (80-100%), Yellow = Medium (40-80%), Red = Low (<40%)
  setRGBColor(255, 255, 0);  // YELLOW - Medium battery (example)
  delay(2000);
  showSystemState();  // Return to normal state
}

// Show error state
void showErrorState() {
  for (int i = 0; i < 5; i++) {
    setRGBColor(255, 0, 0);  // RED - Error
    delay(150);
    rgbOff();
    delay(150);
  }
  showSystemState();  // Return to normal state
}

// Show idle/waiting state
void showIdleState() {
  // Gentle white breathing effect
  for (int brightness = 0; brightness <= 100; brightness += 5) {
    setRGBColor(brightness, brightness, brightness);
    delay(50);
  }
  for (int brightness = 100; brightness >= 0; brightness -= 5) {
    setRGBColor(brightness, brightness, brightness);
    delay(50);
  }
  showSystemState();  // Return to normal state
}

// Blue pulsing effect
void pulseBlue() {
  for (int cycle = 0; cycle < 6; cycle++) {
    // Fade in
    for (int brightness = 0; brightness <= 255; brightness += 5) {
      setRGBColor(0, 0, brightness);
      delay(20);
    }
    // Fade out
    for (int brightness = 255; brightness >= 0; brightness -= 5) {
      setRGBColor(0, 0, brightness);
      delay(20);
    }
  }

  showSystemState();  // Return to normal state
}

// Dedicated 180-degree turn function
void turn180Degrees() {
  // Serial.println("Starting 180-degree turn...");
  updateLCD("TURNING 180", 0, 0, 0, 0, 0);

  // Back up first to create turning space
  // Serial.println("Backing up to create turning space...");
  moveBackward();
  delay(500);  // Back up for half a second
  stopMotors();
  delay(200);

  // Flash RGB to indicate 180-turn in progress with warning pattern
  for (int i = 0; i < 3; i++) {
    setRGBColor(255, 0, 255);  // MAGENTA
    delay(200);
    setRGBColor(255, 255, 0);  // YELLOW
    delay(200);
  }
  setRGBColor(255, 0, 255);  // MAGENTA - 180 turn in progress

  // Perform the 180-degree turn - ignore all sensor readings during this turn
  // Serial.println("Executing 180-degree turn (ignoring sensors)...");
  turnRight();  // Turn right for 180 degrees

  // Turn for a longer time to ensure full 180 degrees
  // Adjust this value based on your robot's actual turning speed
  delay(3500);  // Increased to 3.5 seconds for more reliable 180-degree turn

  stopMotors();
  delay(300);  // Brief pause after turn

  // Turn complete - show success pattern
  // Serial.println("180-degree turn completed!");
  for (int i = 0; i < 3; i++) {
    setRGBColor(0, 255, 0);  // GREEN - Success
    delay(150);
    rgbOff();
    delay(150);
  }
  setRGBColor(0, 255, 0);  // GREEN - Turn completed
  updateLCD("TURN DONE", 0, 0, 0, 0, 0);
  delay(500);         // Show completion status
  showSystemState();  // Return to normal system state
}

void showObstacleDirection(bool leftObstacle, bool frontLeftObstacle,
                           bool frontObstacle, bool frontRightObstacle,
                           bool rightObstacle) {
  // Check if any obstacle is detected
  bool anyObstacle = leftObstacle || frontLeftObstacle || frontObstacle ||
                     frontRightObstacle || rightObstacle;

  if (anyObstacle) {
    // Count number of obstacles for different warning levels
    int obstacleCount = leftObstacle + frontLeftObstacle + frontObstacle +
                        frontRightObstacle + rightObstacle;

    if (obstacleCount >= 3) {
      setRGBColor(255, 0, 0);  // RED - Multiple obstacles (danger)
    } else if (obstacleCount == 2) {
      setRGBColor(255, 100, 0);  // ORANGE - Two obstacles (caution)
    } else {
      setRGBColor(255, 255, 0);  // YELLOW - Single obstacle (warning)
    }
    // Serial.println("RGB: Obstacle warning level: " + String(obstacleCount));
  } else {
    setRGBColor(0, 255, 0);  // GREEN - Path clear
                             // Serial.println("RGB: GREEN - Path clear");
  }
}

// LCD Display function
void updateLCD(String status, long leftDist, long rightDist, long frontDist,
               long frontLeftDist, long frontRightDist) {
  lcd.clear();

  // First line: Left, Front-Left, Front distances
  lcd.setCursor(0, 0);
  lcd.print("L:");
  lcd.print(leftDist);
  lcd.print(",FL:");
  lcd.print(frontLeftDist);
  lcd.print(",F:");
  lcd.print(frontDist);

  // Second line: Front-Right, Right distances and status
  lcd.setCursor(0, 1);
  lcd.print("FR:");
  lcd.print(frontRightDist);
  lcd.print(",R:");
  lcd.print(rightDist);
  lcd.print(" ");
  lcd.print(status.substring(0, 3));  // Show first 3 chars of status
}

// Obstacle avoidance logic
void avoidObstacle() {
  updateLCD("OBSTACLE!", 0, 0, 0, 0, 0);
  stopMotors();
  delay(500);

  // Check all sensors (5 ultrasonic sensors)
  int leftDistance = getDistance(leftTrigPin, leftEchoPin);
  delay(50);
  int rightDistance = getDistance(rightTrigPin, rightEchoPin);
  delay(50);
  int frontDistance = getFrontDistance();  // Use ultrasonic sensor function
  delay(50);                               // Standard ultrasonic delay
  int frontLeftDistance = getDistance(frontLeftTrigPin, frontLeftEchoPin);
  delay(50);
  int frontRightDistance = getDistance(frontRightTrigPin, frontRightEchoPin);
  delay(50);

  // Serial.print("Distances - Left: ");
  // Serial.print(leftDistance);
  // Serial.print(", Front-Left: ");
  // Serial.print(frontLeftDistance);
  // Serial.print(", Front: ");
  // Serial.print(frontDistance);
  // Serial.print(", Front-Right: ");
  // Serial.print(frontRightDistance);
  // Serial.print(", Right: ");
  // Serial.println(rightDistance);

  // Update LCD with actual sensor readings
  updateLCD("OBSTACLE!", leftDistance, rightDistance, frontDistance,
            frontLeftDistance, frontRightDistance);
  delay(1000);  // Show readings for a moment

  // Enhanced decision making based on all sensors
  // Check if left side is clear (both left and front-left)
  if (leftDistance > obstacleThreshold &&
      frontLeftDistance > obstacleThreshold) {
    // Serial.println("Turning Left - Clear path detected");
    updateLCD("TURNING LEFT", leftDistance, rightDistance, frontDistance,
              frontLeftDistance, frontRightDistance);
    turnLeft();
    delay(500);
    stopMotors();
    return;
  }
  // Check if right side is clear (both right and front-right)
  else if (rightDistance > obstacleThreshold &&
           frontRightDistance > obstacleThreshold) {
    // Serial.println("Turning Right - Clear path detected");
    updateLCD("TURNING RIGHT", leftDistance, rightDistance, frontDistance,
              frontLeftDistance, frontRightDistance);
    turnRight();
    delay(500);
    stopMotors();
    return;
  }
  // If front-left is clearer than front-right, turn left
  else if (frontLeftDistance > frontRightDistance &&
           frontLeftDistance > obstacleThreshold) {
    // Serial.println("Turning Left - Front-left clearer");
    updateLCD("TURNING LEFT", leftDistance, rightDistance, frontDistance,
              frontLeftDistance, frontRightDistance);
    turnLeft();
    delay(500);
    stopMotors();
    return;
  }
  // If front-right is clearer than front-left, turn right
  else if (frontRightDistance > frontLeftDistance &&
           frontRightDistance > obstacleThreshold) {
    // Serial.println("Turning Right - Front-right clearer");
    updateLCD("TURNING RIGHT", leftDistance, rightDistance, frontDistance,
              frontLeftDistance, frontRightDistance);
    turnRight();
    delay(500);
    stopMotors();
    return;
  } else {
    // All sides blocked, move backward and try again
    // Serial.println("All sides blocked, backing up");
    updateLCD("BACKING UP", leftDistance, rightDistance, frontDistance,
              frontLeftDistance, frontRightDistance);
    moveBackward();
    delay(500);
    stopMotors();
    delay(500);

    // Try turning around
    // Serial.println("Turning around");
    updateLCD("TURN AROUND", 0, 0, 0, 0, 0);
    turnRight();
    delay(2000);
    stopMotors();
    return;
  }
}

long leftDistance = 0;
long rightDistance = 0;
long frontDistance = 0;
long frontLeftDistance = 0;
long frontRightDistance = 0;

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

    // Check if this could be chunked binary data (first two bytes are chunk
    // metadata)
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
    // Read all front sensors continuously for complete front awareness
    bool frontObstacle =
        getFrontIRObstacle();  // Ultrasonic sensor for front detection
    frontDistance = getFrontDistance();  // Get actual distance for display

    // Always check front-left and front-right ultrasonic sensors
    frontLeftDistance = getDistance(frontLeftTrigPin, frontLeftEchoPin);
    delay(20);
    frontRightDistance = getDistance(frontRightTrigPin, frontRightEchoPin);
    delay(20);

    // Determine front obstacle status
    bool frontLeftObstacle = frontLeftDistance < obstacleThreshold;
    bool frontRightObstacle = frontRightDistance < obstacleThreshold;

    // Check if ALL three front sensors are clear
    bool allFrontClear =
        !frontObstacle && !frontLeftObstacle && !frontRightObstacle;

    // Occasionally check side sensors for awareness (every 5 loops)
    static int sensorCheckCounter = 0;
    sensorCheckCounter++;

    if (sensorCheckCounter >= 5) {
      leftDistance = getDistance(leftTrigPin, leftEchoPin);
      delay(20);
      rightDistance = getDistance(rightTrigPin, rightEchoPin);
      delay(20);
      sensorCheckCounter = 0;
    }

    // Print sensor readings for debugging
    // Serial.print("Front IR: ");
    // Serial.print(frontObstacle ? "BLOCKED" : "CLEAR");
    // Serial.print(", Front-Left: ");
    // Serial.print(frontLeftDistance);
    // Serial.print(" cm, Front-Right: ");
    // Serial.print(frontRightDistance);
    // Serial.print(" cm");

    if (allFrontClear) {
      // Check for side sensor collisions (distance = 0 means very
      // close/touching)
      bool leftCollision =
          (leftDistance <= 5);  // Very close or touching on left
      bool rightCollision =
          (rightDistance <= 5);  // Very close or touching on right

      if (leftCollision && !rightCollision) {
        // Left side collision - turn RIGHT to move away
        digitalWrite(ledPin, HIGH);
        setRGBColor(255, 255, 0);  // YELLOW - Side collision
        updateLCD("LEFT COLLISION", leftDistance, rightDistance, frontDistance,
                  frontLeftDistance, frontRightDistance);
        // Serial.println(" - LEFT SIDE COLLISION, TURNING RIGHT");
        stopMotors();
        turnRight();
        delay(300);  // Turn longer to clear the collision
        stopMotors();
      } else if (rightCollision && !leftCollision) {
        // Right side collision - turn LEFT to move away
        digitalWrite(ledPin, HIGH);
        setRGBColor(255, 255, 0);  // YELLOW - Side collision
        updateLCD("RIGHT COLLISION", leftDistance, rightDistance, frontDistance,
                  frontLeftDistance, frontRightDistance);
        // Serial.println(" - RIGHT SIDE COLLISION, TURNING LEFT");
        stopMotors();
        turnLeft();
        delay(300);  // Turn longer to clear the collision
        stopMotors();
      } else if (leftCollision && rightCollision) {
        // Both sides collision - back up
        digitalWrite(ledPin, HIGH);
        setRGBColor(255, 0, 255);  // MAGENTA - Both sides collision
        updateLCD("BOTH COLLISION", leftDistance, rightDistance, frontDistance,
                  frontLeftDistance, frontRightDistance);
        // Serial.println(" - BOTH SIDES COLLISION, BACKING UP");
        stopMotors();
        moveBackward();
        delay(500);
        stopMotors();
      } else {
        // ALL front sensors clear and no side collisions - safe to move forward
        digitalWrite(ledPin, LOW);
        setRGBColor(0, 255, 0);  // GREEN - Path clear

        updateLCD("FORWARD", leftDistance, rightDistance, frontDistance,
                  frontLeftDistance, frontRightDistance);

        // Serial.println(" - ALL CLEAR, MOVING FORWARD");
        moveForward();
      }
    } else {
      // One or more front sensors blocked - determine turning direction
      digitalWrite(ledPin, HIGH);
      setRGBColor(255, 0, 0);  // RED - Obstacle detected

      // Stop first
      stopMotors();

      // Determine which direction to turn based on which front sensor is
      // blocked
      if (frontObstacle) {
        // Front IR blocked - check sides to determine best turn direction
        if (frontLeftObstacle && !frontRightObstacle) {
          // 2. Front and front-left blocked, front-right clear - turn RIGHT
          updateLCD("TURN RIGHT", leftDistance, rightDistance, frontDistance,
                    frontLeftDistance, frontRightDistance);
          // Serial.println(" - FRONT & FRONT-LEFT BLOCKED, TURNING RIGHT");
          turnRight();
          delay(400);  // Longer turn to clear both obstacles
          stopMotors();
        } else if (frontRightObstacle && !frontLeftObstacle) {
          // 1. Front and front-right blocked, front-left clear - turn LEFT
          updateLCD("TURN LEFT", leftDistance, rightDistance, frontDistance,
                    frontLeftDistance, frontRightDistance);
          // Serial.println(" - FRONT & FRONT-RIGHT BLOCKED, TURNING LEFT");
          turnLeft();
          delay(400);  // Longer turn to clear both obstacles
          stopMotors();
        } else if (frontLeftObstacle && frontRightObstacle) {
          // 3. All three front sensors blocked - DEAD END! Turn 180 degrees
          // Serial.println(  " - DEAD END DETECTED! ALL THREE FRONT SENSORS
          // BLOCKED"); Serial.println(" - EXECUTING EMERGENCY 180-DEGREE
          // TURN");

          // Use dedicated 180-degree turn function
          turn180Degrees();
        } else {
          // Only front IR blocked, sides clear - turn toward clearer side
          if (frontLeftDistance > frontRightDistance) {
            updateLCD("TURN LEFT", leftDistance, rightDistance, frontDistance,
                      frontLeftDistance, frontRightDistance);
            // Serial.println(" - FRONT BLOCKED, TURNING LEFT (CLEARER)");
            turnLeft();
            delay(200);
          } else {
            updateLCD("TURN RIGHT", leftDistance, rightDistance, frontDistance,
                      frontLeftDistance, frontRightDistance);
            // Serial.println(" - FRONT BLOCKED, TURNING RIGHT (CLEARER)");
            turnRight();
            delay(200);
          }
        }
      } else if (frontLeftObstacle && !frontRightObstacle) {
        // Only front-left blocked - turn RIGHT to move away from obstacle
        updateLCD("TURN RIGHT", leftDistance, rightDistance, frontDistance,
                  frontLeftDistance, frontRightDistance);
        // Serial.println(" - FRONT-LEFT BLOCKED, TURNING RIGHT");

        // Turn until front-left is clear, then turn a bit more
        do {
          turnRight();
          delay(100);
          frontLeftDistance = getDistance(frontLeftTrigPin, frontLeftEchoPin);
          delay(20);
          frontLeftObstacle = frontLeftDistance < obstacleThreshold;
        } while (frontLeftObstacle);

        // Front-left is now clear, turn a bit more to avoid side collision
        // Serial.println(
        //     " - FRONT-LEFT CLEAR, TURNING EXTRA TO AVOID SIDE COLLISION");
        turnRight();
        delay(200);  // Extra turn time
        stopMotors();
      } else if (frontRightObstacle && !frontLeftObstacle) {
        // Only front-right blocked - turn LEFT to move away from obstacle
        updateLCD("TURN LEFT", leftDistance, rightDistance, frontDistance,
                  frontLeftDistance, frontRightDistance);
        // Serial.println(" - FRONT-RIGHT BLOCKED, TURNING LEFT");

        // Turn until front-right is clear, then turn a bit more
        do {
          turnLeft();
          delay(100);
          frontRightDistance =
              getDistance(frontRightTrigPin, frontRightEchoPin);
          delay(20);
          frontRightObstacle = frontRightDistance < obstacleThreshold;
        } while (frontRightObstacle);

        // Front-right is now clear, turn a bit more to avoid side collision
        // Serial.println( " - FRONT-RIGHT CLEAR, TURNING EXTRA TO AVOID SIDE
        // COLLISION");
        turnLeft();
        delay(200);  // Extra turn time
        stopMotors();
      } else {
        // Both front-left and front-right blocked but front IR clear
        // This shouldn't happen often, but handle it
        updateLCD("BACK UP", leftDistance, rightDistance, frontDistance,
                  frontLeftDistance, frontRightDistance);
        // Serial.println(" - BOTH SIDES BLOCKED, BACKING UP");
        moveBackward();
        delay(300);
        stopMotors();
        delay(200);
      }

      stopMotors();
    }

  }  // End of autoMode block

  // delay(30);  // Fast loop for responsive control
}

// Chunking support functions
bool processChunkedData(byte *data, int length) {
  if (length < 3) return false;  // Need at least chunk metadata + 1 byte data

  byte chunkNum = data[0];
  byte totalChunks = data[1];

  Serial.println("Received chunk " + String(chunkNum) + "/" +
                 String(totalChunks + 1));

  // First chunk - initialize buffer
  if (chunkNum == 0) {
    resetChunkBuffer();
    chunkBuffer.isActive = true;
    chunkBuffer.totalChunks = totalChunks;
    chunkBuffer.currentChunk = 0;
  }

  // Verify chunk sequence
  if (!chunkBuffer.isActive || chunkNum != chunkBuffer.currentChunk) {
    Serial.println("❌ Chunk sequence error - resetting");
    resetChunkBuffer();
    return false;
  }

  // Add chunk data to buffer (skip first 2 bytes which are metadata)
  for (int i = 2; i < length; i++) {
    chunkBuffer.data += (char)data[i];
  }

  chunkBuffer.currentChunk++;
  chunkBuffer.lastChunkTime = millis();

  // Check if we have all chunks
  if (chunkBuffer.currentChunk > chunkBuffer.totalChunks) {
    String completeCommand = chunkBuffer.data;
    Serial.println("✅ Complete chunked command received: " + completeCommand);
    resetChunkBuffer();

    // Process the complete command
    processBLECommand(completeCommand);
    return true;
  }

  return false;  // Still waiting for more chunks
}

void resetChunkBuffer() {
  chunkBuffer.data = "";
  chunkBuffer.currentChunk = 0;
  chunkBuffer.totalChunks = 0;
  chunkBuffer.isActive = false;
  chunkBuffer.lastChunkTime = 0;
}

bool isChunkTimeout() {
  return chunkBuffer.isActive &&
         (millis() - chunkBuffer.lastChunkTime > CHUNK_TIMEOUT_MS);
}

// ===============================
// ===============================
