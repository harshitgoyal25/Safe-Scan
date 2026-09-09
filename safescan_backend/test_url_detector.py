from app.url_detector import predict_url


test_urls = [
    "https://www.google.com/",
    "https://www.wikipedia.org/",
    "http://example.com/",
    "https://www.python.org/",
    "http://paypal-login-security.example.com/verify/account",
    "http://192.168.1.10/login.php?verify=account&password=123456",
    "http://example.com/download/update.exe",
]


for url in test_urls:
    print("=" * 80)
    print("URL:", url)

    try:
        result = predict_url(url)

        print("Prediction :", result["prediction"])
        print("Probability:", f'{result["probability"]:.6f}')
        print("Threshold  :", result["threshold"])
        print("Word feats :", result["word_features"])
        print("Char feats :", result["char_features"])
        print("Total feats:", result["total_features"])

    except Exception as e:
        print("ERROR:", e)