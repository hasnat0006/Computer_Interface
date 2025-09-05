#include "sensors.h"
#include "config.h"

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
long getFrontDistance() { 
  return getDistance(frontTrigPin, frontEchoPin); 
}
