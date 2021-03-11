# flatmapFromSlices

## Create flatmaps of structures extending through a series of slices

This program was written to create flattened out maps of brain regions throughout numerous slices. The flatmap will show the strength of fluorescence signals in the mapped region as well as the location of silicon probe recording sites.

The program will work just as well with any non-brain-slice data formated the same way.

## Usage

* A program like zen (zeiss) allows you to easily draw a curve or series of line segments onto a microscope scan and export the signal of different fluorescence channels along its length into a .csv file.
* Change the file header to include the measured region's offset in that slice, i.e. 334.85um from the brain midline
```
334.85,
"Distance[µm]","AF488","tdTom","Cy5", , , , 
"0.000","200.143","151.714","1050.286", , , , 
"0.454","201.714","151.429","1025.000", , , , 
...
```

* Put the .csv files into the slices folder and run flatmapFromSlices.pde to create the flatmap.
* To show a recording site or other point of interest, simply cut off your drawn microscope image curve at this site, note down the new curve length, and add it to the first line of the .csv file:
```
650.5, 50_500, 100_550_800, 300, *noStart*line:400*line:540
```

* This example slice would have an offset of 650.5um, 2 shanks of the first probe at distances 50um and 500um, 3 shanks of the second probe at 100um, 550um, and 800um, and one shank of a third probe at 300um.
* Additionally this slice has special additions (\*). It will not show a contour line on its left side (\*nostart) and will show additional lines (\*line:) at 400um and 540um.
* If you want to skip a slice simply use a .csv file like below:
```
0,
"Distance[µm]","AF488","tdTom","Cy5", , , , 
"0.000","0","0","0", , , , 
```

## Configuration

* The color used to plot different channels on the map can be set with the channels array. The following array would not plot the first (distance) and fourth channel, since they are set to black. It would plot the 2nd channel in green and the third channel in red.
```
color[] channels = new color[]{color(0, 0, 0),
                               color(0, 255, 0),
                               color(255, 0, 0),
                               color(0, 0, 0)};
```

* The shanks array works the same way to select colors for shank sites belonging to the same silicon probe.
```
color[] shanks = new color[]{color(0, 255, 255),
                             color(255, 0, 255),
                             color(127, 127, 127)};
```

* inverseOrder = true/false allows you to change the order of slices
* saveFlatmap = true allows saving the created flatmap as a .png and as a .pdf file. The .pdf file can be imported into a vector graphics editor for custom additions.
* showShanks = false allows removing the shank sites from the created flatmap
* interpolatedContour = false will plot the slices as rectangular blocks
* interpolatedContour = true will plot the outline of the flatmap as a continuous line. Special additions (\*) won't be visualized in this mode.