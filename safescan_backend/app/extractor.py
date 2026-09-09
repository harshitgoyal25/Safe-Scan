from pathlib import Path
import json
import pickle

import joblib
import numpy as np
import pandas as pd

from androguard.misc import AnalyzeAPK


# ---------------------------------------------------------
# Paths
# ---------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_DIR = BASE_DIR / "models" / "apk_model"


# ---------------------------------------------------------
# Load model artifacts
# ---------------------------------------------------------

def load_model():
    model_path = MODEL_DIR / "model.pkl"

    try:
        with open(model_path, "rb") as f:
            return pickle.load(f)
    except Exception:
        return joblib.load(model_path)


def load_feature_list(filename):
    path = MODEL_DIR / filename
    df = pd.read_csv(path)

    if df.shape[1] != 1:
        raise ValueError(f"{filename} must contain exactly one column")

    return df.iloc[:, 0].astype(str).tolist()


MODEL = load_model()

SELECTED_FEATURES = load_feature_list("selected_features.csv")
ALL_FEATURES = load_feature_list("feature_names.csv")


# ---------------------------------------------------------
# Validate artifacts
# ---------------------------------------------------------

if len(ALL_FEATURES) != 24833:
    raise ValueError(
        f"Expected 24833 original features, got {len(ALL_FEATURES)}"
    )

if len(SELECTED_FEATURES) != 10000:
    raise ValueError(
        f"Expected 10000 selected features, got {len(SELECTED_FEATURES)}"
    )


FEATURE_INDEX = {
    feature: index
    for index, feature in enumerate(ALL_FEATURES)
}

SELECTED_INDICES = np.array(
    [FEATURE_INDEX[f] for f in SELECTED_FEATURES],
    dtype=np.int32,
)


# ---------------------------------------------------------
# Threshold
# ---------------------------------------------------------

def find_threshold(obj):
    if isinstance(obj, dict):

        # Direct numeric threshold
        for key in [
            "decision_threshold",
            "best_threshold",
            "optimal_threshold",
            "classification_threshold",
        ]:
            if key in obj:
                value = obj[key]

                if isinstance(value, (int, float)):
                    return float(value)

        # Handle:
        # "threshold": {
        #     "value": 0.52
        # }
        if "threshold" in obj:
            threshold = obj["threshold"]

            if isinstance(threshold, (int, float)):
                return float(threshold)

            if isinstance(threshold, dict):
                if "value" in threshold:
                    value = threshold["value"]

                    if isinstance(value, (int, float)):
                        return float(value)

        # Search nested dictionaries
        for value in obj.values():
            result = find_threshold(value)

            if result is not None:
                return result

    return None


with open(MODEL_DIR / "config.json", "r", encoding="utf-8") as f:
    CONFIG = json.load(f)


THRESHOLD = find_threshold(CONFIG)

if THRESHOLD is None:
    raise ValueError(
        "Could not find classification threshold in config.json"
    )


# ---------------------------------------------------------
# Feature normalization
# ---------------------------------------------------------

def normalize_permission(permission):
    if permission.startswith("android.permission."):
        permission = permission[len("android.permission."):]

    return f"Permission::{permission}"


def normalize_intent(intent):
    if intent.startswith("android.intent.action."):
        intent = intent[len("android.intent.action."):]

    return f"Intent::{intent}"


def normalize_api(class_name, method_name):
    class_name = class_name.rstrip(";")

    return f"APICall::{class_name}.{method_name}()"


# ---------------------------------------------------------
# Permission extraction
# ---------------------------------------------------------

def extract_permissions(apk):
    features = set()

    for permission in apk.get_permissions():
        features.add(
            normalize_permission(permission)
        )

    return features


# ---------------------------------------------------------
# Intent extraction
# ---------------------------------------------------------

def extract_intents(apk):
    features = set()

    for item_type in [
        "activity",
        "service",
        "receiver",
        "provider",
    ]:

        try:
            items = apk.get_activities() if item_type == "activity" else []
        except Exception:
            items = []

        try:
            if item_type == "activity":
                names = apk.get_activities()
            elif item_type == "service":
                names = apk.get_services()
            elif item_type == "receiver":
                names = apk.get_receivers()
            elif item_type == "provider":
                names = apk.get_providers()
            else:
                names = []

            for name in names:

                try:
                    filters = apk.get_intent_filters(
                        item_type,
                        name
                    )
                except Exception:
                    continue

                for intent in filters:

                    if isinstance(intent, dict):
                        actions = intent.get("action", [])
                    else:
                        continue

                    if isinstance(actions, str):
                        actions = [actions]

                    for action in actions:
                        features.add(
                            normalize_intent(action)
                        )

        except Exception:
            continue

    return features


# ---------------------------------------------------------
# API extraction
# ---------------------------------------------------------

def extract_api_calls(dx):
    features = set()

    for method_analysis in dx.get_methods():

        try:
            xrefs = method_analysis.get_xref_to()
        except Exception:
            continue

        for xref in xrefs:

            try:
                target = xref[1]
            except Exception:
                continue

            try:
                class_name = target.get_class_name()
                method_name = target.get_name()

                if not class_name or not method_name:
                    continue

                # Only external references are useful here.
                # MH-100K APICall vocabulary is based on API references.
                feature = normalize_api(
                    class_name,
                    method_name
                )

                features.add(feature)

            except Exception:
                continue

    return features


# ---------------------------------------------------------
# APK → 24,833 feature vector
# ---------------------------------------------------------

def extract_full_feature_vector(apk_path):
    apk_path = str(apk_path)

    apk, classes, dx = AnalyzeAPK(apk_path)

    features = set()

    features.update(
        extract_permissions(apk)
    )

    features.update(
        extract_intents(apk)
    )

    features.update(
        extract_api_calls(dx)
    )

    vector = np.zeros(
        len(ALL_FEATURES),
        dtype=np.int8
    )

    matched = 0

    for feature in features:

        index = FEATURE_INDEX.get(feature)

        if index is not None:
            vector[index] = 1
            matched += 1

    return vector, matched


# ---------------------------------------------------------
# APK → final 10,000 model features
# ---------------------------------------------------------

def extract_model_features(apk_path):
    full_vector, matched_features = (
        extract_full_feature_vector(apk_path)
    )

    selected_vector = full_vector[
        SELECTED_INDICES
    ]

    return selected_vector, matched_features


# ---------------------------------------------------------
# Prediction
# ---------------------------------------------------------

def predict_apk(apk_path):

    selected_vector, matched_features = (
        extract_model_features(apk_path)
    )

    if selected_vector.shape != (10000,):
        raise ValueError(
            f"Expected 10000 features, got "
            f"{selected_vector.shape}"
        )

    # Use the same safe feature names used during training.
    columns = [
        f"f_{i}"
        for i in range(10000)
    ]

    X = pd.DataFrame(
        [selected_vector],
        columns=columns
    )

    probabilities = MODEL.predict_proba(X)

    probability = float(
        probabilities[0][1]
    )

    prediction = (
        "Malware"
        if probability >= THRESHOLD
        else "Benign"
    )

    return {
        "prediction": prediction,
        "probability": probability,
        "threshold": float(THRESHOLD),
        "matched_features": int(matched_features),
        "active_features": int(
            selected_vector.sum()
        ),
    }