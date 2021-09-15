'''This scripts contains 2 functions that allow you merging slices or flatmaps.
   combineSlicesToFiles() allows either interpolating 2 slices into a merged new one,
                          or merging any number of entire flatmaps.
   combineSlicesInto2ChannelsToFiles() allows merging 2 flatmaps, but instead of 
   merging the channel signals of the different parents, it will take the same channel from
   both parents and transfer it to different channels of its created flatmap .csv files.
   
   Please set the resolution variable to a value higher than the number of data points in
   your largest input slice before running this code - the new slice will contain this many 
   values/steps along its length'''

resolution = 6000 

import os

def remap(value, inFrom, inTo, outFrom, outTo):
    return outFrom + (outTo - outFrom) * ((value - inFrom) / (inTo - inFrom))

def loadCsvToNestedList(csvPath):
    #the file is encoded in utf-8 since it contains um
    with open(csvPath, encoding='utf-8-sig', errors='ignore') as f:
            lines = f.readlines()
    offset = float(lines[0].split(',')[0])
    newLines = []
    for l, line in enumerate(lines):
        if l<2:
            #ignore the header
            continue
        #save the line as floats in a list - the [1:-1] serves to change "0.000" into 0.000
        line = [float(num[1:-1]) for num in line.split(',')\
                                            if num != ' ' and num != ' \n']
        newLines.append(line)
    #The nested list can be accessed with [line-2][column] (-2 because it has no header)
    return newLines, offset

brainNames = os.listdir(os.path.abspath('./brains'))
brainNames.remove('.gitkeep')
brainPaths = [os.path.join(os.path.abspath('./brains'), bn) for bn in brainNames]
brainSliceNames = [os.listdir(brainPath) for brainPath in brainPaths]
brainSlicePaths = [[os.path.join(brainPath, p) for p in os.listdir(brainPath)] \
                    for brainPath in brainPaths]

#brainSliceNames and brainSlicePaths are nested lists with [brain][slice]
print(f'found brains: {brainNames}')
#print(f'at paths: {brainPaths}')
print(f'with slices: {brainSliceNames}')
#print(f'at paths: {brainSlicePaths}')



def combineSlices(slicePaths): 
    slices = [None for i in range(len(slicePaths))]
    offsets = [None for i in range(len(slicePaths))]
    for i in range(len(slicePaths)):
        slices[i], offsets[i] = loadCsvToNestedList(slicePaths[i])
       
    maxDists = []
    for i in range(len(slices)):
        maxDists.append(slices[i] [len(slices[i])-1] [0])

    for i in range(len(maxDists)):
        print(f'max dist of the slice in brain {i}: {maxDists[i]}')    

    #calculate the average maximum distance and offset for the new combined slice
    maxDistNew = 0
    for i in range(len(slices)):
        maxDistNew += maxDists[i]
    maxDistNew /= len(slices)
    offsetNew = 0
    for i in range(len(slices)):
        offsetNew += offsets[i]
    offsetNew /= len(slices)
    
    combinedLines = []
    combinedLines.append(f'{offsetNew}, \n')
    combinedLines.append('"Distance[um]","AF488","tdTom","Cy5", , , , \n')

    for i in range(resolution):
        #look at the signal i steps (of resolution total steps) into each slice.
        #this point is distances[s] um into slice[s]
        distances = [remap(i, 0, resolution, 0, maxDists[s]) for s in range(len(slices))]
        newDistance = remap(i, 0, resolution, 0, maxDistNew)
        
        #go through the rows of each slice until the row with the current distance is found
        lastRows = [None for s in range(len(slices))]
        for s in range(len(slices)):
            for row in range(len(slices[s])):
                #update the last row
                lastRows[s] = row
                if(slices[s][row][0] > distances[s]):
                    #the row has passed the distance at this step. don't update it further
                    break
        #print(f'last rows: {lastRows}')    

        newLine = f'"{newDistance}",'
        numChannels = len(slices[0][0])-1
        #overwrite the number of processed channels by uncommenting the next line
        #numChannels = 2
        for val in range(1, numChannels+1):
            #for every existing channel add the averaged new value
            value = 0
            for s in range(len(slices)):
                value += slices[s] [lastRows[s]] [val]
            value /= len(slices)
            newLine += f'"{value}",'
        #fill up the other channels/columns with ' ,'
        totalCols = 8
        for column in range(numChannels+1, totalCols-1):
            newLine += ' ,'
        newLine += ' \n'
        
        combinedLines.append(newLine)
        
    return combinedLines


def combineSlicesToFiles():
    '''You can use this function in 2 ways:
         1: Interpolate/merge a single slice from 2 others:
            create 2 folders in the brains folder, i.e. brainA_0 and brainA_1 and put a 
            single slice .csv file into each folder, i.e. brainA_0/slice6.csv and 
            brainA_1/slice8.csv. After running this function it will have created an 
            interpolated .csv file of those 2 slices in the results folder.
         2: Interpolate/merge any number of flatmaps:
            Inside the brains folder create one folder for each original flatmap, i.e.
            brainA, brainB, brainC, and fill these folders with the respective flatmap .csv
            files, i.e. brainA/S00.csv, brainA/S01.csv, brainA/S02.csv...
            When run this function will merge the lexicographically first .csv file of each
            folder into a new interpolated .csv. Then it will merge all 2nd files together, 
            and so on, so please take care to select/name your files according to their 
            alignment. The created new .csv files can be found in the results folder.
            
            Please make sure to have each parent flatmap's signal normalized by running 
            normalizeChannel.py on the flatmap's .csv files before merging flatmap data from
            different experiments.'''
    
    for s in range(len(brainSliceNames[0])):    #for every slice in the first brain
        print(f'Combining ', end = '')
        for b in range(len(brainNames)):
            print(f'brain {brainNames[b]} slice {brainSliceNames[b][s]}', end = '')
            if b != len(brainNames)-1:
                if(b == 0):
                    print(' with ', end='')
                else:
                    print(' and with ', end='')
        print(f' into S{s:02n}')
        #combine the s-th slice from each brain b:
        slicesToMerge = [brainSlicePaths[b][s] for b in range(len(brainSlicePaths))]
        combinedLines = combineSlices(slicesToMerge)
        
        with open(f'./results/S{s:02n}.csv', 'w') as f:
            f.writelines(combinedLines)





def combineSlicesInto2Channels(slicePathA, slicePathB, parentChannel=1):
    sliceA, offsetA = loadCsvToNestedList(slicePathA)
    sliceB, offsetB = loadCsvToNestedList(slicePathB)
            
    maxDistA = sliceA[len(sliceA)-1][0]
    maxDistB = sliceB[len(sliceB)-1][0]
    print(f'max dist of the the first slice: {maxDistA}')    
    print(f'max dist of the the second slice: {maxDistA}')    

    maxDistNew = (maxDistA + maxDistB)/2
    offsetNew = (offsetA + offsetB)/2
    combinedLines = []
    combinedLines.append(f'{offsetNew}, \n')
    combinedLines.append('"Distance[um]","AF488","tdTom","Cy5", , , , \n')
    for i in range(resolution):
        distanceA = remap(i, 0, resolution, 0, maxDistA)
        distanceB = remap(i, 0, resolution, 0, maxDistB)
        newDistance = remap(i, 0, resolution, 0, maxDistNew)
        #go through the rows of A (and B) until the row with the current distance is found
        for rowA in range(len(sliceA)):
            if sliceA[rowA][0] > distanceA:
                break
        for rowB in range(len(sliceB)):
            if sliceB[rowB][0] > distanceB:
                break
        #print(f'last rows: {rowA}, {rowB}')
        newLine = f'"{newDistance}",'
        #add the channel from slice A as value 1
        newLine += f'"{sliceA[rowA][parentChannel]}",'
        #add the channel from slice B as value 2
        newLine += f'"{sliceB[rowB][parentChannel]}",'
        newLine += ' , , , , \n'
        combinedLines.append(newLine)
        
    return combinedLines

def combineSlicesInto2ChannelsToFiles():
    '''Combine 2 flatmaps into a single flatmap with 2 channels. Each parent flatmap will 
       contribute one channel to the new combined flatmap channels.
       Create 2 folders in the brains folder, i.e. brainA and brainB and fill them with
       their respective flatmap .csv files, i.e. brainA/S00.csv, brainA/S01.csv,...
       Then simply run this function to create the combined flatmap .csv files in the
       results folder'''

    for s in range(len(brainSliceNames[0])):
        print(f'combining brain {brainNames[0]} slice {brainSliceNames[0][s]} with ' + 
              f'brain {brainNames[1]} slice {brainSliceNames[1][s]} into S{s:02n}')
        combinedLines = combineSlicesInto2Channels(brainSlicePaths[0][s], 
                                                   brainSlicePaths[1][s])
        with open(f'./results/S{s:02n}.csv', 'w') as f:
            f.writelines(combinedLines)




mergeChannels = True
if mergeChannels:
    #throughout all brains merge their n-th slices together
    combineSlicesToFiles()
else:
    #when merging 2 slices assign each parent's signal to a different channel
    combineSlicesInto2ChannelsToFiles()


