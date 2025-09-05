#ifndef SENSORS_H
#define SENSORS_H

#include <Arduino.h>

// Function declarations for sensor operations
long getDistance(int trigPin, int echoPin);
bool getFrontIRObstacle();
long getFrontDistance();

#endif
