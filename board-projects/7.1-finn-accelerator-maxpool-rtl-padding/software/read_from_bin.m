close all; clear; clc;

C_pre = imread("picture.jpg","jpg");
imshow(C_pre);

H = size(C_pre, 1);
W = size(C_pre, 2);
D = size(C_pre, 3);
P = zeros(H, W, D, "uint8");


fileID = fopen("picture.bin","r");
C = fread(fileID, "uint8");
fclose(fileID);

for i=1:size(P,1)
   for j=1:size(P,2)
       P(i,j,1) = C((i-1)*W*4+(j-1)*4+1);
       P(i,j,2) = C((i-1)*W*4+(j-1)*4+2);
       P(i,j,3) = C((i-1)*W*4+(j-1)*4+3);
    end
end

figure;
imshow(P);

sum(C_pre - P, "all")