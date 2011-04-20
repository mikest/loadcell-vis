/*
loadcell_client - captures data from loadcell_server
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

import processing.serial.*;

Serial myPort;
PrintWriter output;
int traceCount = 0;

// drawing scale in pounds
float maxScale = 0;
float maxTime = 10;

// loadcell parameters
float forceMax = 0;
float forceMin = 0;
float voltageOut = 0;
float voltageRef = 0;
float sampleRate = 0;

// Data received from the serial port
float pounds = 0;
float peak = 0;
int marker = 0;
int running = 0;
double time = 0;
float[] history;
int historyIndex = 0;

boolean armed = false;
float fireDelta = 10.0;  // 10.0Lbs difference
float resetTime = 3.0;    // 3 seconds of stable to disarm

// drawing font
PFont font;
PFont smallFont;
int margin = 15;

void setup() 
{
  size(1200, 600);
  frame.setResizable(true);
  font = loadFont("SansSerif-24.vlw");
  smallFont = loadFont("SansSerif-10.vlw");
  smooth();
  
  // I know that the first port in the serial list on my mac
  // is always my  FTDI adaptor, so I open Serial.list()[0].
  // On Windows machines, this generally opens COM1.
  // Open whatever port is the one you're using.
  String portName = Serial.list()[0];
  myPort = new Serial(this, portName, 115200);
  myPort.bufferUntil('\n');
  
  // write out params for our loadcell
  setLoadCellParameters(3000.0, 30.0, 10.0, 1.1, 30);
}

void serialEvent(Serial p) {
  try
  {
    String[] tokens = splitTokens(myPort.readString(), " ,\t\n");
    if( tokens.length == 3 )
    {
      // update
      time = Float.parseFloat(tokens[0]);
      pounds = Float.parseFloat(tokens[1]);
      marker = Integer.parseInt(tokens[2].trim());
      
      if( running != 0 )
      {
        // peak trace
        if( pounds > peak )
          peak = pounds;
        
        // history sweep
        if( history != null )
        {
          history[historyIndex] = pounds;
                  
          historyIndex++;
          if( historyIndex >= history.length )
            historyIndex = 0;
        }
        
        // file out
        if( output != null )
          output.println(time + "\t" + pounds + "\t" + marker);
      }
    }
  }
  catch(Exception e){ println("invalid packet"); }
  
  // force a redraw
  invalidate();
}


void resize(int w, int h)
{
  frame.setSize(w,h);
}

void keyPressed()
{
  if( key == 'm' )
  {
    myPort.write("M \n");
    
    // start
    if( running == 0 )
    {
      // clear history
      for( int i=0; i<history.length; i++ )
        history[i] = 0;
      historyIndex = 0;
      
      // create writer
      if( output == null )
        output = createWriter("trace-" + traceCount++ + ".txt");
      
      // reset peak
      peak = 0.0;
      maxScale = forceMax/voltageOut * voltageRef;
      
      // start running
      running = 1;
    }
    else
    {
      // already open, flush and close
      if( output != null )
      {
        output.flush();
        output.close();
        output = null;
        running = 0;
      }
    }
  }
  
  if( key == 'p' )
    maxScale = peak;
  
  // high load
  switch( key )
  {
    case '1': setLoadCellParameters(10000.0, 100.0, 10.0, 5.0, 60); break;
    case '2': setLoadCellParameters(10000.0, 100.0, 10.0, 1.1, 60); break;
    case '3': setLoadCellParameters(3000, 30, 10, 5.0, 30); break;
    default: break;
  }
  
  if( key == 'q' )
    exit();
}




void setLoadCellParameters( float fMax, float fMin, float vOut, float vRef, float rate )
{
  // update parameters
  forceMax = fMax;
  forceMin = fMin;
  voltageOut = vOut;
  voltageRef = vRef;
  sampleRate = rate;
  maxScale = forceMax/voltageOut * voltageRef;
  
  // update history
  int count = floor(sampleRate * maxTime);    // three seconds
  history = new float[count];
  historyIndex = 0;
  for( int i=0; i<history.length; i++ )
    history[i] = 0.0;
  
  String s = "P " + forceMax + " " + forceMin + " " + voltageOut
                  + " " + voltageRef + " " + sampleRate + "\n";
             
  myPort.write(s);
}


void drawHistory()
{
  int x = width/5 + margin*2;    // origin
  int y = height - margin;
  int w = width - x - margin;
  int h = height - margin*2;
  
  // draw grid every 100Lbs
  stroke(255);
  fill(255);
  textAlign(RIGHT);
  textFont(smallFont, 10);
  
  // 100 pound horiz lines
  int count = floor(maxScale/100.0);
  for( int i=0; i<=count; i++ )
  {
    float vy = map(i*100,0,maxScale,  0,h);
    line(x, y-vy, x+w, y-vy);
    
    String label = Float.toString(i*100);
    text(label, x-1, y-vy);
  }
  
  // vertical lines
  count = floor(((history.length / sampleRate) + 1) * 2.0);
  for( int i=0; i<=count; i++ )
  {
    float vx = map(i, 0,count,  0,w);
    line(x+vx, y, x+vx, y-h);
    
    String label = Float.toString(i/2.0);
    text(label, x+vx, y+10 );
  }
  
  
  // draw axis
  stroke(0);
  line(x,y,x,margin);
  line(x,y,x+w,h+margin);
  
  // draw history
  if( history != null )
  {
    stroke(255,0,0);
    float lastVal = history[0];
    for( int i=0; i<history.length; i++ )
    {
      float val = history[i];
      float vx = map(i,          0,history.length-1, 0,w);
      float vy = map(val,        0,maxScale,  0,h);
      
      float px = map(i==0?0:i-1, 0,history.length-1, 0,w);
      float py = map(lastVal,    0,maxScale,  0,h);
      
      line(x+px,y-py, x+vx,y-vy);
      
      // sweep line
      if( i == historyIndex )
      {
        line(x+vx,y-vy, x+vx, y);
      }
      
      lastVal = val;
    }
  }
}


void drawBars()
{
  noStroke();
  int h = (height - margin*2);
  int w = width/6;
  
  fill(255);
  int ph = floor(pounds/maxScale * h);
  rect(margin, height-ph - margin, w, ph);
  
  stroke(255,0,0);
  ph = floor(peak/maxScale * h);
  int y = height-ph - margin;
  line(margin, y, margin + w, y);
}


void drawLabels()
{
  textAlign(LEFT);
  textFont(font, 24);
  stroke(0);
  fill(128);
  float t = floor((float)time * 100) / 100.0;
  String label = "LOAD:\n" + Float.toString(pounds) + " Lbs\n" +
    "PEAK:\n" + Float.toString(peak) + " Lbs\n" + 
    "TIME:\n" + Float.toString(t) + " s\n";
  if(output != null )
    label += "(TRACE)";
  else
    label += "(OFF)";
   
  text(label, margin, 50);
}


void draw()
{
  background(200);             // Set background to white
  
  drawHistory();
  drawBars();
  drawLabels();
}

void stop()
{
  if( output != null )
  {
    output.flush();
    output.close();
    output = null;
    
    println("Closing Trace.");
  }
  
  super.stop();
}

