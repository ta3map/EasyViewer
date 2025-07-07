function ICA_components = transformICA(Z_new, W, T, mu)
    Z_new_transposed = Z_new';
    Z_centered = Z_new_transposed - repmat(mu, 1, size(Z_new_transposed, 2));
    Z_transformed = T * Z_centered;
    ICA_components = (W * Z_transformed)';
end
