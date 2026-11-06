close all; clear; clc;
C = imread("afghan-girl.jpg","jpg");
S = sum(C,3);
Under = uint8(S./4);
Over = uint8(S./2);

Gray = uint8(mean(C, 3));
imshow(Over)
figure
imshow(Gray)
figure
imshow(Over)