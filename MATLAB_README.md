# 🚗 Malaysian License Plate Reader

A MATLAB-based application that detects and reads Malaysian vehicle license plates from images, identifies the registered state, and supports batch processing with CSV export. Uses **EasyOCR** (via Python) for text recognition and a custom fallback segmentation method.

---

## 📸 Features

- **Single image detection** — load any image and detect the plate instantly
- **Batch folder processing** — run detection on an entire folder of images at once
- **State identification** — maps plate prefix to Malaysian state (e.g. `W` → Kuala Lumpur, `B` → Selangor)
- **Special plate types** — detects Diplomatic Corps (DC), Taxis (H prefix), Army vehicles, and KLIA Limousines
- **CSV export** — export all results (filename, plate text, state, time taken) to a `.csv` file
- **GUI interface** — clean MATLAB App Designer UI with image previews and results table

---

## 🖥️ How to Run

### Requirements

**MATLAB:**
- MATLAB R2021a or later
- Image Processing Toolbox
- Computer Vision Toolbox
- Text Analytics Toolbox (for `ocr()` fallback)

**Python (for EasyOCR):**
```bash
pip install easyocr opencv-python
```

> MATLAB must be configured to use your Python environment. Set it up with:
> ```matlab
> pyenv('Version', 'path/to/python.exe')
> ```

### Running the App

1. Open MATLAB
2. Navigate to the project folder
3. Run:
```matlab
Plate_reader
```
4. The GUI will open — click **Open Image** to load an image, then **Run Detection**

---

## 📁 Project Structure

```
license-plate-reader/
├── Plate_reader.m        # Main MATLAB app (GUI + all detection logic)
├── detect_plate.py       # Standalone Python script using EasyOCR + OpenCV
├── images/               # Add your own test images here (.jpg, .jpeg, .png)
└── README.md
```

---

## ⚙️ How It Works

1. **Image loaded** → displayed in the GUI
2. **EasyOCR** (Python) scans the image for text regions
3. Regions are filtered by **aspect ratio** (2–6x wide) to identify plate-shaped areas
4. If EasyOCR finds no plate, a **fallback ROI detector** uses binary thresholding + region props
5. The cropped plate is **preprocessed** (contrast enhancement, sharpening, noise reduction)
6. Plate text is cleaned and matched against a **prefix lookup table** to identify the state
7. Results are displayed in the UI and can be exported to CSV

---

## 🗺️ State Prefix Mapping (Sample)

| Prefix | State |
|--------|-------|
| `W` | Kuala Lumpur |
| `B` | Selangor |
| `A` / `F` | Perak |
| `J` | Johor |
| `H` | Taxi |
| `...DC` | Diplomatic Corps |

---

## 📦 Dependencies

| Tool | Purpose |
|------|---------|
| MATLAB Image Processing Toolbox | Preprocessing, morphology, OCR fallback |
| EasyOCR (Python) | Primary text detection |
| OpenCV (Python) | Image loading in standalone script |

---

## ⚠️ Notes

- Test images are not included in this repo — add your own Malaysian plate images into the `images/` folder to test
- Test images in the `images/` folder are used for demonstration purposes only
