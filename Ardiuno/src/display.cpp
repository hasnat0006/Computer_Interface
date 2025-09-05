#include "display.h"
#include <Wire.h>

// LCD Display object
LiquidCrystal_I2C lcd(0x27, 16, 2);

void initializeLCD() {
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
