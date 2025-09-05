#include "rgb_led.h"
#include "config.h"

// RGB LED Control Functions for HW-478 Module
void setRGBColor(int red, int green, int blue) {
  // HW-478 is typically Common Cathode, so HIGH = ON
  // Values: 0-255 for PWM control (0 = off, 255 = full brightness)
  analogWrite(rgbRedPin, red);
  analogWrite(rgbGreenPin, green);
  analogWrite(rgbBluePin, blue);
}

void rgbOff() { 
  setRGBColor(0, 0, 0); 
}

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
  } else {
    setRGBColor(0, 255, 0);  // GREEN - Path clear
  }
}
