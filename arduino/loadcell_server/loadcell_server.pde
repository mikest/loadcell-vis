/*
loadcell_server - captures analog data from a loadcell amp and sends it via serial
Copyright (C) 2011 Mike Estee

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

// our analog input pin
const int analogInPin = A5;
const int markerPin = 13;
int mark = 0;
long time = 0;

// settings for the connected loadcell and analogReference
float forceMax = 3000.0;
float forceMin = 30.0;
float voltageOut = 10.0;
float voltageRef = 1.1;
float sampleRate = 30;

// input
int sensorValue = 0;
float pounds = 0.0;
long lastReadingTime = 0;

// command buffer
const int bufferLen = 256;
char buffer[bufferLen] = "";
int bufferPos = 0;


void setVref( float vref )
{
  if( vref == 1.1 )
    analogReference(INTERNAL);
  else
    analogReference(DEFAULT);
  delay(100);
  analogRead(analogInPin);
  delay(100);
}

void setup()
{
  setVref(voltageRef);
  
  Serial.begin(115200);
  
  // debug
  pinMode(markerPin, OUTPUT);
}

void doCommand(char *buffer)
{
  if( strlen(buffer) > 1 )
  {
    char cmd = 0;
    float value1, value2, value3, value4, value5;
    
    // sscanf %f is missing so we use strtok and atof instead
    const char delim[] = " ,\n";
    char *tok = strtok(buffer, delim);
    if( tok ) cmd = tok[0];
    tok = strtok(NULL, delim);
    if( tok ) value1 = atof(tok);
    tok = strtok(NULL, delim);
    if( tok ) value2 = atof(tok);
    tok = strtok(NULL, delim);
    if( tok ) value3 = atof(tok);
    tok = strtok(NULL, delim);
    if( tok ) value4 = atof(tok);
    tok = strtok(NULL, delim);
    if( tok ) value5 = atof(tok);
    
    // adjust force scales
    if( cmd == 'P' && (value4 == 1.1 || value4 == 5.0))
    {
      forceMax = value1;
      forceMin = value2;
      voltageOut = value3;
      voltageRef = value4;
      sampleRate = value5;
      
      setVref(voltageRef);
    }
    
    // signal a marker
    if( cmd == 'M' )
    {
      mark = 10;    // mark for 10 samples from now
      time = millis();
      digitalWrite(markerPin, HIGH);
    }
  }
}

void loop()
{
  while (Serial.available() > 0)
  {
    int ch = Serial.read();
    
    // flush command on newline or buffer full
    if( ch == -1 || ch == '\n' || (bufferPos>=(bufferLen-1)) )
    {
      buffer[bufferPos] = 0;  // null terminate
      doCommand(buffer);
      bufferPos = 0;  // reset
    }
    else
      buffer[bufferPos++] = ch;
  }
  
  // check for a reading no more than N times a second
  if( (millis() - lastReadingTime) > 1000/sampleRate )    // 120fps
  {
      float elapsedTime = (millis() - time) / 1000.0;
      
      // read the analog in value:
      sensorValue = analogRead(analogInPin); // [0..1023]
//      sensorValue = random(100,150) + abs(sin(elapsedTime*4) * 100.0);
      
      // map it to the range of the analog out:
      float poundsPerVolt = (forceMax/voltageOut);
      float voltage = sensorValue/1024.0 * voltageRef;
      pounds = floor(voltage * poundsPerVolt);
      
      // drop the marker
      if( mark > 0 )
      {
        mark --;
        if( mark == 0 )
          digitalWrite(markerPin, LOW);
      }
      
      // stream the current time in seconds
      Serial.print(elapsedTime);
      Serial.print("\t");
      
      // stream the current load
      Serial.print(pounds);
      
      // stream the current marker
      Serial.print("\t");
      Serial.println(mark>0 ? "1" : "0");
  
      // timestamp the last time you got a reading:
      lastReadingTime = millis();
  }
}
