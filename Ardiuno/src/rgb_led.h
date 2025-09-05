#ifndef RGB_LED_H
#define RGB_LED_H

#include <Arduino.h>

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

#endif
