#include "communication.h"
#include "config.h"
#include "motors.h"
#include "rgb_led.h"

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
