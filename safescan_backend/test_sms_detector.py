from app.sms_detector import predict_sms


print("SafeScan SMS Detector Test")
print("--------------------------")


test_messages = [
    "Hey, are we still meeting for lunch today?",
    "Congratulations! You have won a $1000 prize. Click this link now to claim your reward!",
    "Can you call me when you get home?",
    "URGENT! Your account has been suspended. Call now to restore your account."
]


for message in test_messages:

    result = predict_sms(message)

    print("\nMessage:")
    print(message)

    print("Prediction :", result["prediction"])
    print(
        "Probability:",
        f"{result['probability']:.6f}"
    )
    print(
        "Threshold  :",
        f"{result['threshold']:.2f}"
    )