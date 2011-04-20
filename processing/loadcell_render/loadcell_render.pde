/*
loadcell_render video rendering sketch.
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

import processing.video.*;

String []lines;
Sample []samples;
int sampleCount = 0;
int samplePos = 0;
SteppedMovie movie;
MovieMaker mm;

PFont font;
PFont smallFont;
int margin = 15;

int running = 0;
float peak = 0.0;
float startTime = 0.0;
int startFrame = 0;

void setup()
{
  size(640,480, P2D);
  frameRate(120);
  font = loadFont("SansSerif-24.vlw");
  smallFont = loadFont("SansSerif-10.vlw");
  textMode(SCREEN);
  smooth();
  background(0);
  
    // load the movie
  movie = new SteppedMovie(this, "video.avi", 30);
  movie.precalcFrameTimes(); // you don't <i>have</i> to do this, but it can help performance
  
  // movie writer
  mm = new MovieMaker(this, width, height, "out.mov", 30, MovieMaker.VIDEO, MovieMaker.HIGH);
  
  // load the trace
  boolean mark = false;
  lines = loadStrings("trace.txt");
  samples = new Sample[lines.length];
  for( int i=0; i<lines.length; i++ )
  {
    String[] parts = split(lines[i], '\t');
    Sample s = new Sample(parts);
    if( mark==false && s.mark==1 )      // found first mark
      mark = true;
    
    if( mark )
      samples[sampleCount++] = s;
  }
}

void drawOverlay( Sample s )
{
  // draw visualization
  float h = 100;
  float w = width-margin*2;
  float y = height-(h+margin);
  float x = margin;
  fill(255,255,255,64);
  stroke(255);
  rect(x, y, w, h);    // background
  
  // draw labels
  fill(0);
  textAlign(LEFT, TOP);
  textFont(font, 24);
  
  String label = s.pounds + "";
  text(label, x+margin/2, y + margin/2 );
  
  textFont(smallFont, 10);
  label =
    "PEAK: " + peak + "Lbs\n" +
    "TIME: " + s.time + " sec\n" +
    "FRAME:" + (movie.currentFrameNumber-startFrame);
  text(label, x+margin/2, y+margin/2+24);
  
  // draw graph
}

void drawHistory()
{
  float h = 100;
  float w = width-margin*2 - 100;
  float y = height-margin;
  float x = margin + 100;
  
  float maxScale = 1000.0;
  
  // draw grid every 100Lbs
  stroke(255,255,255,100);
  
  // 100 pound horiz lines
  int count = floor(maxScale/100.0);
  for( int i=0; i<=count; i++ )
  {
    float vy = map(i*100,0,maxScale,  0,h);
    line(x, y-vy, x+w, y-vy);
  }
  
  // vertical lines
  float sampleRate = 30.0;
  count = floor(((sampleCount / sampleRate) + 1) * 2.0);
  for( int i=0; i<=count; i++ )
  {
    float vx = map(i, 0,count,  0,w);
    line(x+vx, y, x+vx, y-h);
  }
  
  // draw history
  fill(255,0,0,128);
  stroke(0);
  beginShape(POLYGON);
  vertex(x,y);
  float lastVal = samples[0].pounds;
  float currentX = 0.0;
  for( int i=0; i<sampleCount; i++ )
  {
    float val = samples[i].pounds;
    float vx = map(i,          0,sampleCount-1, 0,w);
    float vy = map(val,        0,maxScale,  0,h);
    
    float px = map(i==0?0:i-1, 0,sampleCount-1, 0,w);
    float py = map(lastVal,    0,maxScale,  0,h);
    vertex(x+vx,y-vy);
    
    // sweep line
    if( i == samplePos )
      currentX = x+vx;
    
    lastVal = val;
  }
  vertex(x+w,y);
  endShape();
  
  stroke(255,0,0);
  line(currentX,y-h+1, currentX, y);
}

void draw()
{
  background(255);
  
  // movie processing
  movie.read();
  
  // draw the movie
  image(movie, 0, 0, width, height);
  
  // sync sample with movie frame
  float t = (movie.time()/4.0) - startTime;    // 120FPS - > 30FPS
  Sample s = samples[samplePos];
  if( running != 0 )
  {
    if( t > s.time )
    {
      while( t > s.time )
      {
        samplePos++;
        if( samplePos >= sampleCount-1 )
        {
          samplePos = 0;
          mm.finish();
          exit();
        } 
        s = samples[samplePos];
      }
    }
    
    if( s.pounds > peak )
      peak = s.pounds;
  }
  
  drawOverlay(s);
  drawHistory();
  
  // render out frame
  if( running != 0 )
  {
    mm.addFrame();
    movie.stepForward();
  }
}


boolean[] keys = new boolean[526];
void keyPressed()
{
  keys[keyCode] = true;
  
  if (key == 'q' || key == ' ')
  {
    mm.finish();
    exit();
  }
  
  // start processing
  if( key == 'g' )
  {
    running = 1;
    startTime = movie.time()/4.0;
    startFrame = movie.currentFrameNumber;
  }
  
  // search
  if( key == CODED )
  {
    int frame = movie.currentFrameNumber;
    if( keyCode == LEFT )
    {
      if( keys[SHIFT] )
        movie.gotoFrameNumber(frame-10);
      else
        movie.stepBackward();
    }
    
    if( keyCode == RIGHT )
    {
      if( keys[SHIFT] )
        movie.gotoFrameNumber(frame+10);
      else
        movie.stepForward();
    }
  }
}

void keyReleased()
{
  keys[keyCode] = false;
}

class Sample
{
  float time;
  float pounds;
  int mark;
  public Sample(String[] pieces) {
    time = float(pieces[0]);
    pounds = float(pieces[1]);
    mark = int(pieces[2]);
  }
}
