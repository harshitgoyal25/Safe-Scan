from pathlib import Path

import joblib
from scipy.sparse import hstack


# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent.parent

SMS_MODEL_DIR = BASE_DIR / "models" / "sms_model"

MODEL_PATH = SMS_MODEL_DIR / "sms_model.pkl"
WORD_VECTORIZER_PATH = SMS_MODEL_DIR / "sms_word_vectorizer.pkl"
CHAR_VECTORIZER_PATH = SMS_MODEL_DIR / "sms_char_vectorizer.pkl"


# ------------------------------------------------------------
# SafeScan production threshold
# Selected using validation data
# ------------------------------------------------------------

THRESHOLD = 0.40


# ------------------------------------------------------------
# Load model artifacts
# ------------------------------------------------------------

model = joblib.load(MODEL_PATH)

word_vectorizer = joblib.load(
    WORD_VECTORIZER_PATH
)

char_vectorizer = joblib.load(
    CHAR_VECTORIZER_PATH
)


# ------------------------------------------------------------
# SMS prediction
# ------------------------------------------------------------

def predict_sms(message: str) -> dict:
    """
    Predict whether an SMS is benign or malicious.

    Returns:
        prediction
        probability
        threshold
        word_features
        char_features
        total_features
    """

    if not isinstance(message, str):
        raise ValueError("Message must be a string.")

    message = message.strip()

    if not message:
        raise ValueError("Message cannot be empty.")

    # Word TF-IDF
    word_features = word_vectorizer.transform(
        [message]
    )

    # Character TF-IDF
    char_features = char_vectorizer.transform(
        [message]
    )

    # Combine exactly as during training
    combined_features = hstack([
        word_features,
        char_features
    ]).tocsr()

    # Probability of class 1 = malicious
    probability = float(
        model.predict_proba(
            combined_features
        )[0][1]
    )

    # Apply SafeScan threshold
    if probability >= THRESHOLD:
        prediction = "Malicious"
    else:
        prediction = "Benign"

    return {
        "prediction": prediction,
        "probability": probability,
        "threshold": THRESHOLD,
        "word_features": word_features.shape[1],
        "char_features": char_features.shape[1],
        "total_features": combined_features.shape[1],
    }