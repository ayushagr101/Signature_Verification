function [sigma, d0, dlist] = classStats(F)

sigma = std(F, 0, 2);
floorVal = 0.05 * max(std(F(:)), eps);
sigma = max(sigma, max(floorVal, 1e-3));

N = size(F, 2);
dlist = [];
for i = 1:N
    for j = i+1:N
        D = (F(:,i) - F(:,j)) ./ sigma;
        dlist(end+1) = sqrt(mean(D.^2));
    end
end
d0 = max(mean(dlist), 1e-3);
end
