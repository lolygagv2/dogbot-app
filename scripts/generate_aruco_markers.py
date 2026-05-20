#!/usr/bin/env python3
"""
Generate the DICT_4X4_1000 ArUco PNG bundle used by the WIM-Z app's
add-dog flow.

The app loads markers from `assets/markers/aruco_4x4_1000/{id}.png`.
After running this script, uncomment the asset folder declaration in
pubspec.yaml and rebuild:

    flutter:
      assets:
        # ...
        - assets/markers/aruco_4x4_1000/

Requirements:
    pip install opencv-contrib-python

Usage:
    python scripts/generate_aruco_markers.py
        [--count 1000] [--size 600] [--border 1]

Output:
    assets/markers/aruco_4x4_1000/0.png ... 999.png
"""

import argparse
import os
import sys

try:
    import cv2
    from cv2 import aruco
except ImportError:
    sys.stderr.write(
        "OpenCV with aruco support not found. Install with:\n"
        "    pip install opencv-contrib-python\n"
    )
    sys.exit(1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=1000,
                        help="Number of markers to generate (default: 1000)")
    parser.add_argument("--size", type=int, default=600,
                        help="Output PNG side length in pixels (default: 600)")
    parser.add_argument("--border", type=int, default=1,
                        help="Border bits around the marker (default: 1)")
    parser.add_argument("--output", default=None,
                        help="Output directory (default: assets/markers/aruco_4x4_1000/ "
                             "relative to repo root)")
    args = parser.parse_args()

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    out_dir = args.output or os.path.join(
        repo_root, "assets", "markers", "aruco_4x4_1000"
    )
    os.makedirs(out_dir, exist_ok=True)

    aruco_dict = aruco.getPredefinedDictionary(aruco.DICT_4X4_1000)

    written = 0
    for marker_id in range(args.count):
        img = aruco.generateImageMarker(
            aruco_dict, marker_id, args.size, borderBits=args.border
        )
        path = os.path.join(out_dir, f"{marker_id}.png")
        if not cv2.imwrite(path, img):
            sys.stderr.write(f"Failed to write {path}\n")
            return 1
        written += 1
        if written % 100 == 0:
            print(f"  wrote {written}/{args.count}")

    print(f"\nGenerated {written} markers in {out_dir}")
    print("Next: uncomment the marker assets folder in pubspec.yaml and run "
          "`flutter pub get`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
