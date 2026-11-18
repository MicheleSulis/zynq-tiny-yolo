a = fopen('tensors.bin', 'rb');
b = fread(a, 'int8');
fclose(a);

threshold = 0.45;
nmsThreshold = 0.45;
anchors = [10 14; 23 27; 37 58]';
Lblock = 13*13*18;

% Images in the same order as the tensors in tensors.bin.
images = {'file_03250.jpg', 'file_03528.jpg', 'file_03580.jpg'};

for n = 1:numel(images)
    z = reshape(b((n-1)*Lblock+1:n*Lblock), [6 3 13 13]);
    c = z(1:2,:,:,:) / 127;
    for i = 1:13
        for j = 1:13
            c(:,:,i,j) = (c(:,:,i,j) + 0.5 + [i-1; j-1]) * 32;
        end
    end

    s = (z(3:4,:,:,:) / 127 + 1).^2;
    for i = 1:3
        s(:,i,:,:) = s(:,i,:,:) .* anchors(:,i);
    end

    c = reshape(c, 2, []);
    s = reshape(s, 2, []);
    f = reshape(z(5:6,:,:,:), 2, []) / 127 / 2 + 0.5;
    k = find(f(1,:) > threshold);
    boxes = [c-s/2; s]';
    k = k(nms(boxes(k,:), f(1,k), nmsThreshold));

    name = images{n};
    img = imread(name);
    [height, width, ~] = size(img);
    figure
    imshow(img)
    hold on
    for i = k
        r = boxes(i,:) .* ([width height width height] / 416);
        r(1:2) = r(1:2) + 0.5;
        rectangle('Position', r, 'EdgeColor', 'g', 'LineWidth', 1.5);
        text(min(r(1),width-48), max(r(2)-2,24), sprintf('%.2f', f(1,i)), ...
            'VerticalAlignment', 'bottom', 'BackgroundColor', 'g', 'Clipping', 'on');
    end
    hold off

    [~, stem, ext] = fileparts(name);
    exportgraphics(gca, [stem '_nms' ext], ...
        'Width', width, 'Height', height, 'Units', 'pixels', 'Padding', 0);
end

function keep = nms(boxes, scores, threshold)
[~, order] = sort(scores, 'descend');
first = boxes(:,1:2);
last = first + boxes(:,3:4);
area = prod(boxes(:,3:4), 2);
keep = [];
while ~isempty(order)
    i = order(1);
    keep(end+1) = i;
    order = order(2:end);
    overlap = min(last(i,:), last(order,:)) - max(first(i,:), first(order,:));
    intersection = prod(max(overlap, 0), 2);
    iou = intersection ./ (area(i) + area(order) - intersection);
    order = order(iou <= threshold);
end
end
