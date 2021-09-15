'''Use this script to read in a folder of slice data .csv files and create new .csv 
   files with the signal of the selected channel normalized into the range 0.0 to 1.0 
   across all slices. 
   This normalization is important to use before running combineSlices.py, since
   different experiments can originally contain data in different ranges.'''

#The .csv file column/channel, which is is to be normalized across all slices:
channel = 1

import os

def remap(value, inFrom, inTo, outFrom, outTo):
    return outFrom + (outTo - outFrom) * ((value - inFrom) / (inTo - inFrom))

def loadCsvToNestedList(csvPath):
    #the file is encoded in utf-8 since it contains um
    with open(csvPath, encoding='utf-8-sig', errors='ignore') as f:
            lines = f.readlines()
    header = [lines[0], lines[1]]
    newLines = []
    for l, line in enumerate(lines):
        if l<2:
            #keep the 2 header lines as is
            continue
        #save the line as floats in a list - the [1:-1] serves to change "0.000" into 0.000
        line = [float(num[1:-1]) for num in line.split(',')\
                                            if num != ' ' and num != ' \n']
        newLines.append(line)
    #The nested list can be accessed with [line-2][column] (-2 because it has no header)
    return newLines, header

slicesFolder = os.path.abspath('./slices')
sliceNames = os.listdir(slicesFolder)
sliceNames.remove('.gitkeep')
slicePaths = [os.path.join(slicesFolder, sn) for sn in sliceNames]
print(f'Normalizing column {channel} signal throughout {len(slicePaths)} ' +\
      f'slices at: {slicePaths}')

def normalizeSlices(slicePaths, sliceNames, channel=1):
    slicesData = []
    slicesHeader = []
    for sp in slicePaths:
        data, header = loadCsvToNestedList(sp)
        slicesData.append(data)
        slicesHeader.append(header)

    minVal = 1_000_000
    maxVal = 0
    #print(slicesData[0][0])                 #the first non-header row of the first slice
    for i in range(len(slicesData)):         #for each slice
        for j in range(len(slicesData[i])):  #for each row
            val = slicesData[i][j][channel]  #i.e. channel=1 could be the AF488 channel
            minVal = min(minVal, val)
            maxVal = max(maxVal, val)
    print(f'minimum value: {minVal} will be normalized to 0.0')
    print(f'maximum value: {maxVal} will be normalized to 1.0')       
    #min and max line up with the min and max printed out when running flatmapFromSlices.pde
    
    #now create the normalized .csv files:
    for i in range(len(slicesData)):
        newLines = slicesHeader[i]
        for j in range(len(slicesData[i])):
            line = f'"{slicesData[i][j][0]}",'
            #flatmapFromSlices.pde also normalized to 0 to 1 for the lerpColor()
            normalizedValue = remap(slicesData[i][j][channel], minVal, maxVal, 0.0, 1.0)
            line += f'"{normalizedValue}", , , , , , \n'
            newLines.append(line)
        
        resultPath = os.path.abspath('./results')
        resultPath = os.path.join(resultPath, f'{sliceNames[i]}')
        with open(resultPath, 'w') as f:
            f.writelines(newLines)
     

normalizeSlices(slicePaths, sliceNames, channel=channel)
