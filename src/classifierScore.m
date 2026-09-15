function p = classifierScore(clf, X)

if isvector(X) && numel(X) == numel(clf.mu), X = X(:)'; end
Xs = bsxfun(@rdivide, bsxfun(@minus, X, clf.mu), clf.sd);

switch lower(clf.type)
    case 'logistic'
        p = 1 ./ (1 + exp(-(Xs * clf.w(2:end) + clf.w(1))));
    case 'svm'
        [~, post] = predict(clf.svm, Xs);
        p = post(:, 2);
    otherwise
        error('classifierScore:type', 'Unknown classifier type "%s".', clf.type);
end
p = min(max(p(:), 0), 1);
end
