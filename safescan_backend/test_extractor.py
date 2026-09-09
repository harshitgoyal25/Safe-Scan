from app.extractor import predict_apk

APK_PATH = r"D:\test.apk"

result = predict_apk(APK_PATH)

print("\nSafeScan extraction test")
print("------------------------")
print(f"Prediction        : {result['prediction']}")
print(f"Probability       : {result['probability']:.6f}")
print(f"Threshold         : {result['threshold']:.6f}")
print(f"Matched features  : {result['matched_features']}")
print(f"Active features   : {result['active_features']}")