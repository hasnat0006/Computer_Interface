#include "motors.h"
#include "config.h"
#include "display.h"
#include "rgb_led.h"

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
    analogWrite(enC, vacuumSpeed * 0.8);  // Reduce vacuum speed to 80%
  }
  if (mopEnabled) {
    analogWrite(enD, mopSpeed * 0.7);  // Reduce mop speed to 70%
  }
  if (pumpEnabled) {
    analogWrite(enE, pumpSpeed * 0.7);  // Reduce pump speed to 70%
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
    analogWrite(enC, vacuumSpeed * 0.8);  // Reduce vacuum speed to 80%
  }
  if (mopEnabled) {
    analogWrite(enD, mopSpeed * 0.7);  // Reduce mop speed to 70%
  }
  if (pumpEnabled) {
    analogWrite(enE, pumpSpeed * 0.7);  // Reduce pump speed to 70%
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
    analogWrite(enC, vacuumSpeed * 0.7);  // Reduce vacuum speed to 70%
  }
  if (mopEnabled) {
    analogWrite(enD, mopSpeed * 0.6);  // Reduce mop speed to 60%
  }
  if (pumpEnabled) {
    analogWrite(enE, pumpSpeed * 0.6);  // Reduce pump speed to 60%
  }

  analogWrite(enA, motorSpeed * 1.15);
  analogWrite(enB, motorSpeed * 1.15);
  // SWAPPED: Left motor backward, right motor forward (to turn left)
  digitalWrite(in1, HIGH);
  digitalWrite(in2, LOW);
  digitalWrite(in3, LOW);
  digitalWrite(in4, HIGH);
}

void turnRight() {
  // Reduce cleaning motor speeds when turning to save power
  if (vacuumEnabled) {
    analogWrite(enC, vacuumSpeed * 0.7);  // Reduce vacuum speed to 70%
  }
  if (mopEnabled) {
    analogWrite(enD, mopSpeed * 0.6);  // Reduce mop speed to 60%
  }
  if (pumpEnabled) {
    analogWrite(enE, pumpSpeed * 0.6);  // Reduce pump speed to 60%
  }

  analogWrite(enA, motorSpeed * 1.15);
  analogWrite(enB, motorSpeed * 1.15);
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

// Dedicated 180-degree turn function
void turn180Degrees() {
  updateLCD("TURNING 180", 0, 0, 0, 0, 0);

  // Back up first to create turning space
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
  turnRight();  // Turn right for 180 degrees

  // Turn for a longer time to ensure full 180 degrees
  delay(3500);  // 3.5 seconds for more reliable 180-degree turn

  stopMotors();
  delay(300);  // Brief pause after turn

  // Turn complete - show success pattern
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
