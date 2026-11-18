close all; clear; clc;
C = imread("picture.jpg","jpg");

fileID = fopen("picture.bin","a+");
for i=1:size(C,1)
    for j=1:size(C,2)
        fwrite(fileID, C(i,j,1));
        fwrite(fileID, C(i,j,2));
        fwrite(fileID, C(i,j,3));
    end
end
fclose(fileID);