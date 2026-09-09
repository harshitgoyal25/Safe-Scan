from pathlib import Path

import joblib
from scipy.sparse import hstack


BASE_DIR = Path(__file__).resolve().parent.parent
URL_MODEL_DIR = BASE_DIR / "models" / "url_model"

MODEL_PATH = URL_MODEL_DIR / "url_model.pkl"
WORD_VECTORIZER_PATH = URL_MODEL_DIR / "url_word_vectorizer.pkl"
CHAR_VECTORIZER_PATH = URL_MODEL_DIR / "url_char_vectorizer.pkl"

THRESHOLD = 0.41


# Load artifacts once when the backend starts.
model = joblib.load(MODEL_PATH)
word_vectorizer = joblib.load(WORD_VECTORIZER_PATH)
char_vectorizer = joblib.load(CHAR_VECTORIZER_PATH)


def predict_url(url: str) -> dict:
    if not isinstance(url, str):
        raise ValueError("URL must be a string.")

    url = url.strip()

    if not url:
        raise ValueError("URL cannot be empty.")

    if len(url) > 10000:
        raise ValueError("URL is too long.")

    # Generate exactly the same TF-IDF representation
    # used during model training.
    word_features = word_vectorizer.transform([url])
    char_features = char_vectorizer.transform([url])

    combined_features = hstack(
        [word_features, char_features]
    ).tocsr()

    probability = float(
        model.predict_proba(combined_features)[0][1]
    )

    prediction = (
        "Malicious"
        if probability >= THRESHOLD
        else "Benign"
    )

    return {
        "prediction": prediction,
        "probability": probability,
        "threshold": THRESHOLD,
        "word_features": word_features.shape[1],
        "char_features": char_features.shape[1],
        "total_features": combined_features.shape[1],
    }