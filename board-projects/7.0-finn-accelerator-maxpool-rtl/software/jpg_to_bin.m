N = 3;
images = {'file_03250.jpg', 'file_03528.jpg', 'file_03580.jpg'};

fileID = fopen('../firmware/pictures.bin', 'wb');
for n = 1:N
    C = imresize(imread(images{n}), [416 416]);
    fwrite(fileID, permute(C, [3 2 1]), 'uint8');
end
fclose(fileID);
