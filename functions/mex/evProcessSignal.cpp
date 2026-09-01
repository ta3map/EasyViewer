#include "mex.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <string>
#include <vector>

static std::vector<double> getVector(const mxArray* arr) {
    std::vector<double> v;
    if (arr == nullptr || mxIsEmpty(arr)) {
        return v;
    }
    const size_t n = mxGetNumberOfElements(arr);
    v.resize(n);
    std::memcpy(v.data(), mxGetPr(arr), n * sizeof(double));
    return v;
}

static std::vector<bool> getLogicalMask(const mxArray* arr, size_t expectedLen) {
    std::vector<bool> mask(expectedLen, true);
    if (arr == nullptr || mxIsEmpty(arr)) {
        return mask;
    }
    const mxLogical* p = mxGetLogicals(arr);
    const size_t n = mxGetNumberOfElements(arr);
    mask.assign(expectedLen, false);
    for (size_t i = 0; i < std::min(n, expectedLen); ++i) {
        mask[i] = p[i] != 0;
    }
    return mask;
}

static void normalizeBa(std::vector<double>& b, std::vector<double>& a) {
    const double a0 = a[0];
    for (size_t i = 0; i < b.size(); ++i) {
        b[i] /= a0;
    }
    for (size_t i = 0; i < a.size(); ++i) {
        a[i] /= a0;
    }
}

static void padCoeffs(std::vector<double>& b, std::vector<double>& a) {
    const size_t nfilt = std::max(a.size(), b.size());
    if (b.size() < nfilt) {
        b.resize(nfilt, 0.0);
    }
    if (a.size() < nfilt) {
        a.resize(nfilt, 0.0);
    }
}

static std::vector<double> lfilterZi(const std::vector<double>& b, const std::vector<double>& a) {
    const size_t nfilt = std::max(a.size(), b.size());
    const size_t order = nfilt - 1;
    if (order == 0) {
        return {};
    }

    std::vector<std::vector<double>> m(order, std::vector<double>(order, 0.0));
    for (size_t i = 0; i < order; ++i) {
        m[i][0] = 1.0 + a[i + 1];
    }
    for (size_t i = 1; i < order; ++i) {
        m[i][0] = a[i + 1];
        m[i][i] = 1.0;
        m[i - 1][i] = -1.0;
    }

    std::vector<double> rhs(order, 0.0);
    for (size_t i = 0; i < order; ++i) {
        rhs[i] = b[i + 1] - b[0] * a[i + 1];
    }

    std::vector<double> zi = rhs;
    for (size_t k = 0; k < order; ++k) {
        size_t pivot = k;
        for (size_t i = k + 1; i < order; ++i) {
            if (std::abs(m[i][k]) > std::abs(m[pivot][k])) {
                pivot = i;
            }
        }
        if (std::abs(m[pivot][k]) < 1e-30) {
            continue;
        }
        if (pivot != k) {
            std::swap(m[k], m[pivot]);
            std::swap(zi[k], zi[pivot]);
        }
        for (size_t i = k + 1; i < order; ++i) {
            const double f = m[i][k] / m[k][k];
            for (size_t j = k; j < order; ++j) {
                m[i][j] -= f * m[k][j];
            }
            zi[i] -= f * zi[k];
        }
    }

    for (int k = static_cast<int>(order) - 1; k >= 0; --k) {
        double sum = zi[static_cast<size_t>(k)];
        for (size_t j = static_cast<size_t>(k) + 1; j < order; ++j) {
            sum -= m[static_cast<size_t>(k)][j] * zi[j];
        }
        zi[static_cast<size_t>(k)] = sum / m[static_cast<size_t>(k)][static_cast<size_t>(k)];
    }

    return zi;
}

static std::vector<double> lfilter(
    const std::vector<double>& b,
    const std::vector<double>& a,
    const std::vector<double>& x,
    const std::vector<double>& ziIn) {
    const size_t n = x.size();
    const size_t nfilt = std::max(a.size(), b.size());
    const size_t order = nfilt - 1;
    std::vector<double> z = ziIn;
    if (z.size() < order) {
        z.resize(order, 0.0);
    }
    std::vector<double> y(n, 0.0);

    for (size_t i = 0; i < n; ++i) {
        const double xi = x[i];
        y[i] = b[0] * xi + z[0];
        if (order == 0) {
            continue;
        }
        for (size_t j = 0; j + 1 < order; ++j) {
            z[j] = z[j + 1] + b[j + 1] * xi - a[j + 1] * y[i];
        }
        z[order - 1] = b[order] * xi - a[order] * y[i];
    }
    return y;
}

static std::vector<double> filtfiltCore(const std::vector<double>& bIn, const std::vector<double>& aIn, const std::vector<double>& xIn) {
    std::vector<double> b = bIn;
    std::vector<double> a = aIn;
    normalizeBa(b, a);
    padCoeffs(b, a);

    const size_t lx = xIn.size();
    const size_t nfilt = std::max(b.size(), a.size());
    const int lrefl = static_cast<int>(std::max<size_t>(1, 3 * (nfilt - 1)));
    if (static_cast<int>(lx) <= lrefl) {
        return xIn;
    }

    std::vector<double> xt;
    xt.reserve(lx + 2 * static_cast<size_t>(lrefl));
    for (int i = lrefl; i >= 1; --i) {
        xt.push_back(2.0 * xIn[0] - xIn[static_cast<size_t>(i)]);
    }
    for (size_t i = 0; i < lx; ++i) {
        xt.push_back(xIn[i]);
    }
    for (int i = 1; i <= lrefl; ++i) {
        xt.push_back(2.0 * xIn[lx - 1] - xIn[lx - 1 - static_cast<size_t>(i)]);
    }

    const std::vector<double> ziBase = lfilterZi(b, a);
    std::vector<double> zi = ziBase;
    for (auto& v : zi) {
        v *= xt.front();
    }
    std::vector<double> y = lfilter(b, a, xt, zi);
    std::reverse(y.begin(), y.end());

    zi = ziBase;
    for (auto& v : zi) {
        v *= y.front();
    }
    y = lfilter(b, a, y, zi);
    std::reverse(y.begin(), y.end());

    return std::vector<double>(y.begin() + lrefl, y.begin() + lrefl + static_cast<int>(lx));
}

static std::vector<double> reflectPad(const std::vector<double>& x, int reflectionLength) {
    const size_t n = x.size();
    if (reflectionLength <= 0 || n == 0) {
        return x;
    }
    const int refl = std::min(reflectionLength, static_cast<int>(n));
    std::vector<double> out(2 * static_cast<size_t>(refl) + n);
    for (int i = 0; i < refl; ++i) {
        out[static_cast<size_t>(i)] = x[static_cast<size_t>(refl - 1 - i)];
        out[n + static_cast<size_t>(refl) + static_cast<size_t>(i)] = x[n - 1 - static_cast<size_t>(i)];
    }
    for (size_t i = 0; i < n; ++i) {
        out[static_cast<size_t>(refl) + i] = x[i];
    }
    return out;
}

static std::vector<double> filtfiltColumn(const std::vector<double>& b, const std::vector<double>& a, const std::vector<double>& x) {
    const int reflectionLength = static_cast<int>(std::round(x.size() * 0.10));
    const std::vector<double> padded = reflectPad(x, reflectionLength);
    const std::vector<double> filtered = filtfiltCore(b, a, padded);
    const size_t start = static_cast<size_t>(reflectionLength);
    const size_t end = filtered.size() - static_cast<size_t>(reflectionLength);
    return std::vector<double>(filtered.begin() + start, filtered.begin() + end);
}

static void movmeanShrink(std::vector<double>& col, int span) {
    const size_t n = col.size();
    const int half = span / 2;
    std::vector<double> out(n, 0.0);
    for (size_t i = 0; i < n; ++i) {
        const int iInt = static_cast<int>(i);
        const int start = std::max(0, iInt - half);
        const int end = std::min(static_cast<int>(n) - 1, iInt + half);
        double sum = 0.0;
        int count = 0;
        for (int j = start; j <= end; ++j) {
            sum += col[static_cast<size_t>(j)];
            ++count;
        }
        out[i] = sum / static_cast<double>(count);
    }
    col.swap(out);
}

static double medianOf(std::vector<double>& values) {
    const size_t mid = values.size() / 2;
    std::nth_element(values.begin(), values.begin() + static_cast<std::ptrdiff_t>(mid), values.end());
    if (values.size() % 2 == 0) {
        const double upper = values[mid];
        std::nth_element(values.begin(), values.begin() + static_cast<std::ptrdiff_t>(mid - 1), values.end());
        return (values[mid - 1] + upper) * 0.5;
    }
    return values[mid];
}

static void medfilt1Column(std::vector<double>& col, int span) {
    const size_t n = col.size();
    if (span % 2 == 0) {
        ++span;
    }
    const int half = span / 2;
    std::vector<double> out(n, 0.0);
    for (size_t i = 0; i < n; ++i) {
        const int iInt = static_cast<int>(i);
        std::vector<double> window;
        window.reserve(static_cast<size_t>(span));
        for (int j = iInt - half; j <= iInt + half; ++j) {
            window.push_back((j >= 0 && j < static_cast<int>(n)) ? col[static_cast<size_t>(j)] : 0.0);
        }
        out[i] = medianOf(window);
    }
    col.swap(out);
}

static double linearInterp(const std::vector<double>& tOrig, const std::vector<double>& yOrig, double t) {
    const size_t n = tOrig.size();
    if (t <= tOrig.front()) {
        return yOrig.front() + (yOrig[1] - yOrig.front()) * (t - tOrig.front()) / (tOrig[1] - tOrig.front());
    }
    if (t >= tOrig.back()) {
        return yOrig[n - 1] + (yOrig[n - 1] - yOrig[n - 2]) * (t - tOrig[n - 1]) / (tOrig[n - 1] - tOrig[n - 2]);
    }
    const auto it = std::upper_bound(tOrig.begin(), tOrig.end(), t);
    const size_t hi = static_cast<size_t>(it - tOrig.begin());
    const size_t lo = hi - 1;
    const double frac = (t - tOrig[lo]) / (tOrig[hi] - tOrig[lo]);
    return yOrig[lo] + frac * (yOrig[hi] - yOrig[lo]);
}

static void resampleColumns(std::vector<std::vector<double>>& columns, double sourceFs, double targetFs) {
    const size_t n = columns[0].size();
    const int newFsInt = static_cast<int>(std::round(targetFs));
    const int numPoints = static_cast<int>(std::round((static_cast<double>(n) - 1.0) * newFsInt / sourceFs)) + 1;
    std::vector<double> tOrig(n);
    std::vector<double> tRes(numPoints);
    for (size_t i = 0; i < n; ++i) {
        tOrig[i] = static_cast<double>(i) / sourceFs;
    }
    for (int i = 0; i < numPoints; ++i) {
        tRes[static_cast<size_t>(i)] = static_cast<double>(i) / static_cast<double>(newFsInt);
    }
    for (auto& col : columns) {
        std::vector<double> out(numPoints, 0.0);
        for (int i = 0; i < numPoints; ++i) {
            out[static_cast<size_t>(i)] = linearInterp(tOrig, col, tRes[static_cast<size_t>(i)]);
        }
        col.swap(out);
    }
}

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
    if (nrhs < 9) {
        mexErrMsgIdAndTxt("evProcessSignal:args", "Nine inputs required.");
    }

    const size_t nRows = mxGetM(prhs[0]);
    const size_t nCols = mxGetN(prhs[0]);
    const double* dataIn = mxGetPr(prhs[0]);

    const std::vector<double> b = getVector(prhs[1]);
    const std::vector<double> a = getVector(prhs[2]);
    const bool doFilter = !b.empty() && !a.empty();
    const std::vector<bool> columnMask = getLogicalMask(prhs[3], nCols);

    const int span = static_cast<int>(std::round(mxGetScalar(prhs[4])));
    const char* smoothMethod = mxArrayToString(prhs[5]);
    const bool smoothEnabled = mxIsLogical(prhs[6]) ? mxGetLogicals(prhs[6])[0] != 0 : mxGetScalar(prhs[6]) != 0.0;
    const double targetFs = mxGetScalar(prhs[7]);
    const double sourceFs = mxGetScalar(prhs[8]);

    const bool smoothOn = smoothEnabled && span >= 5;
    const bool useMedian = std::string(smoothMethod) == "median";

    std::vector<std::vector<double>> columns(nCols);
    for (size_t c = 0; c < nCols; ++c) {
        columns[c].resize(nRows);
        for (size_t r = 0; r < nRows; ++r) {
            columns[c][r] = dataIn[r + c * nRows];
        }
    }

    for (size_t c = 0; c < nCols; ++c) {
        if (!columnMask[c]) {
            continue;
        }
        if (doFilter) {
            columns[c] = filtfiltColumn(b, a, columns[c]);
        }
        if (!smoothOn) {
            continue;
        }
        if (useMedian) {
            medfilt1Column(columns[c], span);
        } else {
            movmeanShrink(columns[c], span);
        }
    }

    if (std::round(sourceFs) != std::round(targetFs)) {
        resampleColumns(columns, sourceFs, targetFs);
    }

    const size_t outRows = columns.empty() ? 0 : columns[0].size();
    plhs[0] = mxCreateDoubleMatrix(outRows, nCols, mxREAL);
    double* dataOut = mxGetPr(plhs[0]);
    for (size_t c = 0; c < nCols; ++c) {
        for (size_t r = 0; r < outRows; ++r) {
            dataOut[r + c * outRows] = columns[c][r];
        }
    }

    if (nlhs >= 2) {
        plhs[1] = mxCreateDoubleMatrix(0, 0, mxREAL);
    }

    mxFree(const_cast<char*>(smoothMethod));
}
