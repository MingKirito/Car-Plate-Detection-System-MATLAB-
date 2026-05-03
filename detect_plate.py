import os
import easyocr
import cv2

# Initialize EasyOCR reader
reader = easyocr.Reader(['en'])

# Define the directory containing your images
image_directory = r"C:\Users\Aspire E15 Acer User\Document\MATLAB\tests\Train\images"

# Ensure the results directory exists
save_path = r"C:/Users/Aspire E15 Acer User/Desktop/IPPR Assignment/tests/Train/images/results"
os.makedirs(save_path, exist_ok=True)  # Create the directory if it doesn't exist

# Loop through all images in the directory
for filename in os.listdir(image_directory):
    # Check if the file is an image (e.g., .jpg, .jpeg, .png)
    if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
        img_path = os.path.join(image_directory, filename)
        img = cv2.imread(img_path)
        
        # Check if the image is loaded properly
        if img is None:
            print(f"Error loading image: {filename}")
            continue
        
        # Detect text (license plate)
        results = reader.readtext(img)
        
        # Loop through the results and display the bounding boxes for detected text
        for (bbox, text, prob) in results:
            if prob > 0.5:  # Adjust the probability threshold
                
                # Draw bounding box around detected text (convert to integers)
                top_left = tuple(map(int, bbox[0]))  # Convert to integers
                bottom_right = tuple(map(int, bbox[2]))  # Convert to integers
                cv2.rectangle(img, top_left, bottom_right, (0, 255, 0), 2)

        # Save the processed image with bounding boxes
        result_filename = os.path.join(save_path, f"result_{filename}")
        cv2.imwrite(result_filename, img)
        print(f"Saved result for {filename} at {result_filename}")
