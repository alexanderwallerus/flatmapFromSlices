//Functions for parsing folders:
String[] listFileNames(String dir){  //return all files in a directory as Str Array
  File file = new File(dir);
  if (file.isDirectory()) {
    String names[] = file.list();
    return names;
  } else {
    return null;  //If it's not a directory
  }
}

File[] listFiles(String dir){  //return all files in a directory as File object Array
  File file = new File(dir);   //=> useful for showing more info about the files
  if (file.isDirectory()) {
    File[] files = file.listFiles();
    return files;
  } else {
    return null;   //If it's not a directory
  }
}

ArrayList<File> listFilesRecursive(String dir){ //=> list of all files in a directory
  ArrayList<File> fileList = new ArrayList<File>();  //and all subdirecties
  recurseDir(fileList, dir);
  return fileList;
}

void recurseDir(ArrayList<File> a, String dir){  //Recursive function to traverse 
  File file = new File(dir);                     //subdirectories
  if (file.isDirectory()) {
    //If you want to include directories in the list
    a.add(file);  
    File[] subfiles = file.listFiles();
    for (int i = 0; i < subfiles.length; i++) {
      //Call this function on all files in this directory
      recurseDir(a, subfiles[i].getAbsolutePath());
    }
  } else {
    a.add(file);
  }
}
