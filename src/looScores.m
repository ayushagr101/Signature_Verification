function out = looScores(model)

N = size(model.F, 2);
for i = 1:N
    keep = true(1, N); keep(i) = false;
    sub = model;
    sub.F = model.F(:, keep);
    sub.refImgs = model.refImgs(keep);
    [sub.sigma, sub.d0] = classStats(sub.F);
    s = signatureScore(sub, model.F(:, i), model.refImgs{i});
    if i == 1
        out = s;
    else
        out(i) = s;
    end
end
end
