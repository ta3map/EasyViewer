# HEKA to UDF Converter

Converter for transforming HEKA data (.mat files) to Universal Data Format (UDF).

## Location

The converter is located in the `heka_udf_converter/` folder and represents a separate Python package.

## Quick Start

```bash
# Navigate to converter folder
cd heka_udf_converter

# Install dependencies
pip install -r requirements_converter.txt

# Run example
python example_heka_to_udf.py
```

## Usage in Code

```python
from heka_udf_converter import load_mat_file, heka_to_udf

# Load HEKA file
mat_data = load_mat_file("path/to/heka_file.mat")

# Convert to UDF
udf_data = heka_to_udf(mat_data, "path/to/heka_file.mat")
```

## Detailed Documentation

See [README_converter.md](heka_udf_converter/README_converter.md) for detailed documentation.

## Features

- ✅ Sweep preservation in `[time, channels, sweeps]` format
- ✅ Automatic unit detection
- ✅ Support for MAT files v7.3 and earlier versions
- ✅ Minimal metadata (only real data)
- ✅ Clean modular code

