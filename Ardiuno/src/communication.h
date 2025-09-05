#ifndef COMMUNICATION_H
#define COMMUNICATION_H

#include <Arduino.h>
#include <ArduinoJson.h>

// Function declarations for BLE communication
void processBLECommand(String command);
void processJsonCommand(String jsonString);
bool isValidJson(String jsonString);
void processShortJsonCommand(StaticJsonDocument<1024> &doc, String action);
void processLongJsonCommand(StaticJsonDocument<1024> &doc, String action);
void handleMoveCommand(String direction);
void sendStatusResponse();

// Chunking support function declarations
bool processChunkedData(byte *data, int length);
void resetChunkBuffer();
bool isChunkTimeout();

#endif
