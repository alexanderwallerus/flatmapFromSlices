//Code by Alexander Wallerus
//MIT license

import processing.pdf.*;

//set the colors for each fluorescence channel/.csv file column with
//this array. If a channel is not to be used set it to black = color(0).
color[] channels = new color[]{color(0),
                               color(0, 255, 0),
                               color(255, 0, 0),
                               color(0)};

//colors for the shanks of different recording silicon probes inserted into the tissue
color[] shanks = new color[]{color(0, 255, 255),
                             color(255, 0, 255),
                             color(127)};

boolean inverseOrder = false;    //flip the top and bottom of the flatmap
boolean saveFlatmap = true;
String saveName = "flatmap";
boolean showShanks = true;
boolean interpolatedContour = true;

float scaling = 1.0/3.0;         //0.3333... um per Pixel
PImage completeFlatmap;
float scalebarTheta = 0;

void setup(){
  size(2500, 1000);
  
  //load the slice data from the .csv files
  Slice[] slices = loadFiles();
  
  //find the minimum and maximum channel signal throughout all slices.
  //A microscope recording 14bit fluorescence channels covers a range of 2^14 = 16_384
  PVector[] minMaxSignal = findMinMaxSignal(slices);
  
  makePlots(slices, channels, scaling, minMaxSignal, shanks);
  completeFlatmap = get();
  println("plot complete");
}

void draw(){
  image(completeFlatmap, 0, 0);
  pushMatrix();
    translate(mouseX, mouseY-25);
    rotate(scalebarTheta);
    drawScaleBar(new PVector(), scaling);
  popMatrix();
}

void mouseWheel(MouseEvent event){
  float count = event.getCount();
  scalebarTheta += count/20;
}

class Slice{
  float offset;
  Table vals;
  ArrayList<PVector> shankSites = new ArrayList<PVector>(); //type index and distance
  boolean noStart = false;
  boolean noEnd = false;
  FloatList additionalLines = new FloatList();
  String fileName;

  Slice(float offset_, Table vals_, String fileName_){
    offset = offset_;
    vals = vals_;
    fileName = fileName_;
  }
}

class LineSegment{
  PVector from, to;
  LineSegment(PVector from_, PVector to_){
    from = from_;  to = to_;
  }
}

void makePlots(Slice[] slices, color[] channels, float scaling,
               PVector[] minMaxSignal, color[] shankCols){
  
  PVector plotPos = new PVector(100, 50); //the topleft start of the plot =>
                                          //the alignement line starts here
  float slicesOffset = 30;                //the current plotting level on y.
                                          //each slice will increment this value
  PFont f = createFont("Arial Bold", 20); //this font has μ = \u03BC 
  float sliceThickness = 70;              //70um
  
  //variables for the interpolated contour
  FloatList start = new FloatList();      //plot start and end positions of each slice
  FloatList end = new FloatList();
  IntList startCol = new IntList();       //first and last colors of each slice
  IntList endCol = new IntList();
  ArrayList<LineSegment> contour = new ArrayList<LineSegment>();    //the contour
  
  if(saveFlatmap){
    String date = str(year()) + nf(month(), 2) + nf(day(), 2);
    saveName += "_" + date;
    beginRecord(PDF, "flatmaps\\" + saveName + ".pdf");
  }
  
  
  println("starting plotting the flatmap");
  background(0);
  for(int i=0; i<slices.length; i++){
    Slice s = slices[i];
    textFont(f, 20);
    textAlign(RIGHT, TOP);
    fill(255);
    text(s.fileName, plotPos.x -10, plotPos.y + slicesOffset);
    
    for(int row=0; row<s.vals.getRowCount(); row++){
      //get the current distance along the curve
      float dist = s.vals.getRow(row).getFloat(0);
      dist *= scaling;
      
      //calculate the color for this distance
      color combinedCol = color(0);
      for(int chan=0; chan<channels.length; chan++){
        float value = s.vals.getRow(row).getFloat(chan);
        if(Float.isNaN(value)){
          //there are more colors in the channels array than filled in value columns 
          //in the table. Without values there is nothing to plot
          continue;
        }
        //normalize the signal to between 0 and 1 throughout the entire plot
        value = map(value, minMaxSignal[chan].x, minMaxSignal[chan].y, 0, 1);
        //use this value to set the channel color from black=0 to full=1
        color col = lerpColor(color(0), channels[chan], value);
        //the plotted color is the maximum projection of all colors at this spot
        combinedCol = color(max(red(combinedCol), red(col)),
                            max(green(combinedCol), green(col)),
                            max(blue(combinedCol), blue(col)));
      }
      
      //store the edge color for the interpolated contour drawing
      if(row == 0){
        startCol.append(combinedCol);
      } 
      if (row == s.vals.getRowCount()-1){
        endCol.append(combinedCol);
      }
      
      //draw the current signal color
      fill(combinedCol);  noStroke();
      rect(plotPos.x + (s.offset * scaling) + dist,
           plotPos.y + slicesOffset, 1, sliceThickness * scaling);                 
    }
    
    //draw the lines bordering the plot
    stroke(0, 255, 255);
    strokeWeight(2);
    strokeCap(ROUND);
    //draw the center line
    line(plotPos.x, plotPos.y + slicesOffset,
         plotPos.x, plotPos.y + slicesOffset + (sliceThickness * scaling));
         
    if(!interpolatedContour){
      if(!s.noStart){
        line(plotPos.x + (s.offset * scaling), plotPos.y + slicesOffset,
             plotPos.x + (s.offset * scaling), 
             plotPos.y + slicesOffset + (sliceThickness * scaling));
      }
      if(!s.noEnd){
        float maxDist = s.vals.getRow(s.vals.getRowCount()-1).getFloat(0);
        line(plotPos.x + ((s.offset + maxDist) * scaling), plotPos.y + slicesOffset,
             plotPos.x + ((s.offset + maxDist) * scaling), 
             plotPos.y + slicesOffset + (sliceThickness * scaling));
      }
      
      //draw additional lines if existent
      for(float line : s.additionalLines){
        line(plotPos.x + ((s.offset + line) * scaling), plotPos.y + slicesOffset,
             plotPos.x + ((s.offset + line) * scaling), 
             plotPos.y + slicesOffset + (sliceThickness * scaling));
      }
    } else {
      
     
      //draw the interpolated contour along the edge of all slices
      pushStyle();
      float prevY = plotPos.y + slicesOffset - (0.5 * sliceThickness * scaling);
      float y = plotPos.y + slicesOffset + (0.5 * sliceThickness * scaling);
      //y and prevY are at the center point of their respective slice thickness
      float maxDist = s.vals.getRow(s.vals.getRowCount()-1).getFloat(0);

      if(i==0){
        //the previous slice is projected to continue the contour's trend => 
        //start + (start - nextStart) => 0.5 * line length to keep it within the plot 
        start.append(      (plotPos.x + (s.offset * scaling)) +
                     0.5* ((plotPos.x + (s.offset * scaling)) - 
                           (plotPos.x + (slices[i+1].offset * scaling))));
        prevY += 0.5 * sliceThickness * scaling;

        float nextMaxDist = slices[i+1].vals.getRow(slices[i+1].vals.getRowCount()-1)
                                                                    .getFloat(0);
        end.append(      (plotPos.x + ((s.offset + maxDist) * scaling)) +
                   0.5* ((plotPos.x + ((s.offset + maxDist) * scaling)) - 
                         (plotPos.x + ((slices[i+1].offset + nextMaxDist)*scaling))));
                          
        //add a line on the top edge of the flatmap
        contour.add(new LineSegment(new PVector(start.get(i), prevY), 
                                    new PVector(end.get(i), prevY)));      
      }
      //the start/end index (line points) is +1 of the slice index, due to starting 
      //half a slice/one point earlier than the existing slices

      //add the current slice start and end points
      start.append(plotPos.x + (s.offset * scaling));
      end.append(plotPos.x + (s.offset + maxDist) * scaling);
      
      if(s.offset == 0.0){
        //this slice's data is missing. interpolate it from adjacent slices
        float nextStart = plotPos.x + (slices[i+1].offset * scaling);
        float nextMaxDist = slices[i+1].vals.getRow(slices[i+1].vals.getRowCount()-1)
                                            .getFloat(0);
        float nextEnd = plotPos.x + ((slices[i+1].offset + nextMaxDist) * scaling);
        
        //overwrite the slice's start and end values with the interpolated ones
        start.set(i+1, lerp(start.get(i), nextStart, 0.5));
        end.set(i+1, lerp(end.get(i), nextEnd, 0.5));
      }

      //add the line from the previous slice to the current one to the contour
      contour.add(new LineSegment(new PVector(start.get(i), prevY), 
                                  new PVector(start.get(i+1), y)));   
      contour.add(new LineSegment(new PVector(end.get(i), prevY), 
                                  new PVector(end.get(i+1), y)));   

      //extend the color at the edges
      rectMode(CORNERS);
      if(s.offset != 0.0){    //offset=0 slices would draw into the alignment line 
        fill(startCol.get(i));  noStroke();
        rect(plotPos.x + (s.offset * scaling), plotPos.y + slicesOffset, 
             plotPos.x + 20, plotPos.y + slicesOffset + (sliceThickness * scaling));
        fill(endCol.get(i));  noStroke();
        rect(plotPos.x + ((s.offset + maxDist) * scaling), 
             plotPos.y + slicesOffset, width-20, 
             plotPos.y + slicesOffset + (sliceThickness * scaling));
      }
           
      //trim the color to the inside of the contour
      fill(0);  noStroke();
      beginShape();
        //the +-1 pixel takes care of float imprecision
        vertex(start.get(i), prevY -1);
        vertex(plotPos.x + 19, prevY -1);
        vertex(plotPos.x + 19, y +1);
        vertex(start.get(i+1), y +1);
      endShape(CLOSE);
      beginShape();
        vertex(end.get(i), prevY -1);
        vertex(width - 19, prevY -1);
        vertex(width - 19, y +1);
        vertex(end.get(i+1), y +1);
      endShape(CLOSE);

      if(i == slices.length-1){
        //the next slice is projected to continue the contour's trend => 
        //start + (start - prevStart) => again go only 50% of the way
        start.append(start.get(i+1) + 0.5*(start.get(i+1) - start.get(i)));
        float nextY = plotPos.y + slicesOffset + (1.0 * sliceThickness * scaling);
        contour.add(new LineSegment(new PVector(start.get(i+1), y), 
                                    new PVector(start.get(i+2), nextY)));
        
        end.append(end.get(i+1) + 0.5*(end.get(i+1) - end.get(i)));
        contour.add(new LineSegment(new PVector(end.get(i+1), y), 
                                    new PVector(end.get(i+2), nextY))); 
                                    
        //trim the color to the inside of the contour on the last half-slice
        beginShape();
          vertex(start.get(i+1), y -1);
          vertex(plotPos.x + 19, y -1);
          vertex(plotPos.x + 19, nextY +1);
          vertex(start.get(i+2), nextY +1);
        endShape(CLOSE);
        beginShape();
          vertex(end.get(i+1), y -1);
          vertex(width - 19, y -1);
          vertex(width - 19, nextY +1);
          vertex(end.get(i+2), nextY +1);
        endShape(CLOSE);        
      }
      popStyle(); 
    }
    
    
    println("slice " + s.fileName + " complete");
    //increment the slice offset
    slicesOffset += sliceThickness * scaling;
  }
  
  if(interpolatedContour){
    //draw the stored contour lines
    stroke(0, 255, 255);
    strokeWeight(2);
    strokeCap(ROUND);
    for(int c=0; c<contour.size(); c++){
      line(contour.get(c).from.x, contour.get(c).from.y, 
           contour.get(c).to.x, contour.get(c).to.y);
    }
  }
  
  //draw shank sites on top if they exist
  slicesOffset = 30;        //reset the y offset and run through all slices again
  for(Slice s : slices){    //=> shank sites get drawn on top of everything else
    if(showShanks){
      for(PVector shankSite : s.shankSites){
        //get the color from the type of the shank and the shank color array
        stroke(shankCols[int(shankSite.x)]);
        noFill();    strokeWeight(3);    ellipseMode(CENTER);
        ellipse(plotPos.x + ((s.offset + shankSite.y) * scaling), 
                plotPos.y + slicesOffset + (0.5 * sliceThickness * scaling), 
                sliceThickness * scaling *0.86, sliceThickness * scaling * 0.86);
                //draw ellipses slightly smaller (*0.86) to avoid the stroke thickness 
                //reaching into adjacent slices
      }
    }
    slicesOffset += sliceThickness * scaling;
  }
  
  //add the scalebar
  drawScaleBar(new PVector(1000, 30).add(plotPos), scaling);
    
  if(saveFlatmap){
    //calculate the width of the image to be saved
    float recordDist = 0;
    for(Slice s : slices){
      recordDist = max(recordDist, 
                       s.offset + s.vals.getRow(s.vals.getRowCount()-1).getFloat(0));
    }

    recordDist *= scaling;
    recordDist += plotPos.x + 500;  //this value can be reduced or increased for a
                                    //better image framing
    //save the .pdf
    endRecord();
    //save the .png
    PImage flatmap = get(int(plotPos.x) - 50, int(plotPos.y),
                         max(int(recordDist), int(plotPos.x + 50)), 
                         int(plotPos.y + slicesOffset - 20));
    flatmap.save("flatmaps\\" + saveName +  ".png");
  }
}

void drawScaleBar(PVector pos, float scaling){
  PFont f = createFont("Arial Bold", 20);
  textFont(f);
  textAlign(CENTER, TOP);
  textLeading(40);
  fill(255, 0, 0);  noStroke();
  String scaleInfo = "500μm\n" + nf(scaling, 0, 2) + "μm per pixel";
  text(scaleInfo, pos.x, pos.y);
  float lineLength = 500 * scaling; 
  strokeWeight(4);
  stroke(255, 0, 0);
  strokeCap(SQUARE);
  line(pos.x - (lineLength/2), pos.y + 27, pos.x + (lineLength/2), pos.y + 27);
  line(pos.x - (lineLength/2), pos.y + 27-10, pos.x - (lineLength/2), pos.y + 27+10);
  line(pos.x + (lineLength/2), pos.y + 27-10, pos.x + (lineLength/2), pos.y + 27+10);
}

Slice[] loadFiles(){
  String slicesPath = sketchPath() + "\\slices";
  String[] fileNames = listFileNames(slicesPath);
  fileNames = subset(fileNames, 1, fileNames.length-1);  //get rid of the .gitignore
  fileNames = sort(fileNames);
  if(inverseOrder){
    fileNames = reverse(fileNames);
  }
  
  Slice[] slices = new Slice[fileNames.length];
  
  //enter every file's data into the corresponding slice object
  for(int i=0; i<slices.length; i++){
    String filePath = slicesPath + "\\" + fileNames[i];
    String fileName = fileNames[i].substring(0, fileNames[i].length()-4);//remove .csv
    Table tab = loadTable(filePath);   
    TableRow header = new Table().addRow(tab.getRow(0));
    tab.removeRow(0);                                    //remove the 2 header lines
    tab.removeRow(0);
    float offset = header.getFloat(0);
    
    slices[i] = new Slice(offset, tab, fileName);
        
    for(int col=1; col<header.getColumnCount(); col++){
      //additional info starts in column 1 => go through all remaining columns
      if((header.getString(col) != null) && (!header.getString(col).equals(""))){  
        //There is data in this column
        //every column before the *-column contains shanks of the one probe
        if(header.getString(col).trim().charAt(0)!='*'){
          //store the index and position of each shank in a vector
          String[] shankGroup = trim(header.getString(col).split("_"));
          for(String shank : shankGroup){
            slices[i].shankSites.add(new PVector(col-1, float(shank)));
            println("Slice " + fileName + " has a shank belonging to probe " + 
                    (col-1) + " at distance " + shank + "um.");
          }
        } else {
          //this column contains custom modifications to be made to the flatmap
          String[] modifications = trim(header.getString(col).split("\\*"));
          for(String mod : modifications){
            if(mod.equals("")){
              continue;
            } else if(mod.equals("noStart")){
              slices[i].noStart = true;
            } else if(mod.equals("noEnd")){
              slices[i].noEnd = true;
            } else if(mod.substring(0, 4).equals("line")){
              float linePos = float(mod.split(":")[1].trim());
              slices[i].additionalLines.append(linePos);
            }
          }
        }
      }
    }
  }
  return slices;
}

PVector[] findMinMaxSignal(Slice[] slices){
  PVector[] minMaxSignal = new PVector[channels.length];

  for(int chan=0; chan<channels.length; chan++){
    println("searching for the minimum and maximal signal in channel " + chan);
    float maxSignal = 0;
    float minSignal = 16384;
    //the maximum fluorescence in a 14 bit channel is (2^14)-1 = 16.383
    for(Slice s : slices){
      for(int row=0; row<s.vals.getRowCount(); row++){
        maxSignal = max(maxSignal, s.vals.getRow(row).getFloat(chan));
        minSignal = min(minSignal, s.vals.getRow(row).getFloat(chan));
      }
    }
    println("the maximal signal for channel " + chan + " is " + maxSignal);
    println("the minimal signal for channel " + chan + " is " + minSignal);
    minMaxSignal[chan] = new PVector(minSignal, maxSignal);
  }
  return minMaxSignal;
}
