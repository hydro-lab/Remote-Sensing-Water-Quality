import os
import numpy as np
import rasterio

# The first time I tried this, I used tifffile, which needed imagecodecs.  Rasterio does not need imagecodecs.  Details are provided as notes (nothing here needs to be used with rasterio).
# import tifffile as tiff
# you must have the following installed, which is used by tifffile, but not required and not imported.
# pip install imagecodecs
# there is a check to verify installation.  Run in a notebook:
# import imagecodecs
# print(imagecodecs.__version__)
# This should yield something with the year and version numbers.

# Specify the full paths of the input and output directories.  Different directories are used for checking output; the filenames are appended and you can combine the image files in the same directory after processing.
input_folder = "/Users/yourusername/Documents/data/turbidity_images"
output_folder = "/Users/yourusername/Documents/data/rotated_images"

os.makedirs(output_folder, exist_ok=True)

# Rotation mapping (k = number of 90° rotations)
rotations = {
    90: 1,
    180: 2,
    270: 3
}

for filename in os.listdir(input_folder):
    if filename.lower().endswith(".tif"):
        input_path = os.path.join(input_folder, filename)

        with rasterio.open(input_path) as src:
            data = src.read()  # shape: (bands, height, width)
            profile = src.profile

            for angle, k in rotations.items():
                # Rotate spatial dimensions ONLY
                rotated = np.rot90(data, k=k, axes=(1, 2))

                # Update height/width
                new_height, new_width = rotated.shape[1], rotated.shape[2]

                new_profile = profile.copy()
                new_profile.update({
                    "height": new_height,
                    "width": new_width
                })

                name, ext = os.path.splitext(filename)
                output_path = os.path.join(
                    output_folder,
                    f"{name}_rot{angle}{ext}"
                )

                with rasterio.open(output_path, "w", **new_profile) as dst:
                    dst.write(rotated)

        print(f"Processed: {filename}")
