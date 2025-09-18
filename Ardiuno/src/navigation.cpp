#include "navigation.h"
#include "config.h"
#include "sensors.h"
#include "motors.h"
#include "rgb_led.h"
#include "display.h"

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

  // Enhanced decision making based on all sensors
  // Check if left side is clear (both left and front-left)
  if (leftDistance > obstacleThreshold &&
      frontLeftDistance > obstacleThreshold) {
    // TURNING LEFT
    turnLeft();
    delay(300);
    stopMotors();
    return;
  }
  // Check if right side is clear (both right and front-right)
  else if (rightDistance > obstacleThreshold &&
           frontRightDistance > obstacleThreshold) {
    // TURNING RIGHT
    turnRight();
    delay(300);
    stopMotors();
    return;
  }
  // If front-left is clearer than front-right, turn left
  else if (frontLeftDistance > frontRightDistance &&
           frontLeftDistance > obstacleThreshold) {
    // TURNING LEFT
    turnLeft();
    delay(300);
    stopMotors();
    return;
  }
  // If front-right is clearer than front-left, turn right
  else if (frontRightDistance > frontLeftDistance &&
           frontRightDistance > obstacleThreshold) {
    // TURNING RIGHT
    turnRight();
    delay(300);
    stopMotors();
    return;
  } else {
    // All sides blocked, move backward and try again
    // BACKING UP
    moveBackward();
    delay(300);
    stopMotors();
    delay(300);

    // Try turning around
    // TURN AROUND
    turnRight();
    delay(1500);
    stopMotors();
    return;
  }
}

// Autonomous navigation logic (extracted from main loop)
void autonomousNavigation() {
  static long leftDistance = 0;
  static long rightDistance = 0;
  static long frontDistance = 0;
  static long frontLeftDistance = 0;
  static long frontRightDistance = 0;
  
  // Read all front sensors continuously for complete front awareness
  bool frontObstacle = getFrontIRObstacle();  // Ultrasonic sensor for front detection
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
  bool allFrontClear = !frontObstacle && !frontLeftObstacle && !frontRightObstacle;

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

  if (allFrontClear) {
    // Check for side sensor collisions (distance = 0 means very close/touching)
    bool leftCollision = (leftDistance <= 5);  // Very close or touching on left
    bool rightCollision = (rightDistance <= 5);  // Very close or touching on right

    if (leftCollision && !rightCollision) {
      // Left side collision - turn RIGHT to move away
      digitalWrite(ledPin, HIGH);
      setRGBColor(255, 255, 0);  // YELLOW - Side collision
      // updateLCD("LEFT COLLISION", leftDistance, rightDistance, frontDistance,
      //           frontLeftDistance, frontRightDistance);
      stopMotors();
      turnRight();
      delay(100);  // Reduced rotation to avoid over-turning
      stopMotors();
    } else if (rightCollision && !leftCollision) {
      // Right side collision - turn LEFT to move away
      digitalWrite(ledPin, HIGH);
      setRGBColor(255, 255, 0);  // YELLOW - Side collision
      // updateLCD("RIGHT COLLISION", leftDistance, rightDistance, frontDistance,
      //           frontLeftDistance, frontRightDistance);
      stopMotors();
      turnLeft();
      delay(100);  // Reduced rotation to avoid over-turning
      stopMotors();
    } else if (leftCollision && rightCollision) {
      // Both sides collision - back up
      digitalWrite(ledPin, HIGH);
      setRGBColor(255, 0, 255);  // MAGENTA - Both sides collision
      // updateLCD("BOTH COLLISION", leftDistance, rightDistance, frontDistance,
      //           frontLeftDistance, frontRightDistance);
      stopMotors();
      moveBackward();
      delay(300);
      stopMotors();
    } else {
      // ALL front sensors clear and no side collisions - safe to move forward
      digitalWrite(ledPin, LOW);
      setRGBColor(0, 255, 0);  // GREEN - Path clear

      // updateLCD("FORWARD", leftDistance, rightDistance, frontDistance,
      //           frontLeftDistance, frontRightDistance);

      moveForward();
    }
  } else {
    // One or more front sensors blocked - determine turning direction
    digitalWrite(ledPin, HIGH);
    setRGBColor(255, 0, 0);  // RED - Obstacle detected

    // Stop first
    stopMotors();

    // Determine which direction to turn based on which front sensor is blocked
    if (frontObstacle) {
      // Front IR blocked - check sides to determine best turn direction
      if (frontLeftObstacle && !frontRightObstacle) {
        // Front and front-left blocked, front-right clear - turn RIGHT
        // updateLCD("TURN RIGHT", leftDistance, rightDistance, frontDistance,
        //           frontLeftDistance, frontRightDistance);
        turnRight();
        delay(200);  // Longer turn to clear both obstacles
        stopMotors();
      } else if (frontRightObstacle && !frontLeftObstacle) {
        // Front and front-right blocked, front-left clear - turn LEFT
        // updateLCD("TURN LEFT", leftDistance, rightDistance, frontDistance,
        //           frontLeftDistance, frontRightDistance);
        turnLeft();
        delay(200);  // Longer turn to clear both obstacles
        stopMotors();
      } else if (frontLeftObstacle && frontRightObstacle) {
        // All three front sensors blocked - DEAD END! Turn 180 degrees
        turn180Degrees();
      } else {
        // Only front IR blocked, sides clear - turn toward clearer side
        if (frontLeftDistance > frontRightDistance) {
          // updateLCD("TURN LEFT", leftDistance, rightDistance, frontDistance,
          //           frontLeftDistance, frontRightDistance);
          turnLeft();
          delay(150);
        } else {
          // updateLCD("TURN RIGHT", leftDistance, rightDistance, frontDistance,
          //           frontLeftDistance, frontRightDistance);
          turnRight();
          delay(150);
        }
      }
    } else if (frontLeftObstacle && !frontRightObstacle) {
      // Only front-left blocked - turn RIGHT to move away from obstacle
      // updateLCD("TURN RIGHT", leftDistance, rightDistance, frontDistance,
                // frontLeftDistance, frontRightDistance);

      // Turn until front-left is clear, then turn a bit more
      do {
        turnRight();
        delay(100);
        frontLeftDistance = getDistance(frontLeftTrigPin, frontLeftEchoPin);
        delay(20);
        frontLeftObstacle = frontLeftDistance < obstacleThreshold;
      } while (frontLeftObstacle);

      // Front-left is now clear, turn a bit more to avoid side collision
      turnRight();
      delay(150);  // Extra turn time
      stopMotors();
    } else if (frontRightObstacle && !frontLeftObstacle) {
      // Only front-right blocked - turn LEFT to move away from obstacle
      // updateLCD("TURN LEFT", leftDistance, rightDistance, frontDistance,
      //           frontLeftDistance, frontRightDistance);

      // Turn until front-right is clear, then turn a bit more
      do {
        turnLeft();
        delay(100);
        frontRightDistance = getDistance(frontRightTrigPin, frontRightEchoPin);
        delay(20);
        frontRightObstacle = frontRightDistance < obstacleThreshold;
      } while (frontRightObstacle);

      // Front-right is now clear, turn a bit more to avoid side collision
      turnLeft();
      delay(150);  // Extra turn time
      stopMotors();
    } else {
      // Both front-left and front-right blocked but front IR clear
      // updateLCD("BACK UP", leftDistance, rightDistance, frontDistance,
      //           frontLeftDistance, frontRightDistance);
      moveBackward();
      delay(200);
      stopMotors();
      delay(150);
    }

    stopMotors();
  }
}
